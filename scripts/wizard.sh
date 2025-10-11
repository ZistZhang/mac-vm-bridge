#!/usr/bin/env bash
set -euo pipefail

GREEN="\033[32m"; YELL="\033[33m"; RED="\033[31m"; BLUE="\033[34m"; NC="\033[0m"
ok(){ echo -e "${GREEN}✓${NC} $*"; }
warn(){ echo -e "${YELL}⚠${NC} $*"; }
err(){ echo -e "${RED}✗${NC} $*"; }
info(){ echo -e "${BLUE}ℹ${NC} $*"; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs"; mkdir -p "$LOG_DIR"
STATE_FILE="$ROOT/state.json"
PID_FILE="$ROOT/qemu.pid"
REPORT_FILE="$ROOT/report.md"

BRIDGE_IF=""
CIDR_BASE="192.168.200"
SERVER_IP="${CIDR_BASE}.131"
WIN_IP="${CIDR_BASE}.2"
# Host-side SSH forward port for the QEMU user-net. We will probe and auto-adjust.
SSH_PORT=2222
SKIP_CONFLICT=0
VM_NAME=""

save_state(){ echo "{\"stage\":\"$1\",\"timestamp\":$(date +%s)}" > "$STATE_FILE"; }
load_state(){ [ -f "$STATE_FILE" ] && jq -r .stage "$STATE_FILE" 2>/dev/null || echo "init"; }


check_deps() {
  local missing=()
  for c in jq nc expect; do
    command -v "$c" >/dev/null 2>&1 || missing+=("$c")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    err "缺少依赖: ${missing[*]}。请先运行 ./scripts/bootstrap.sh"
    exit 1
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cidr) CIDR_BASE="$2"; SERVER_IP="${CIDR_BASE}.131"; WIN_IP="${CIDR_BASE}.2"; shift 2 ;;
      --server-ip) SERVER_IP="$2"; shift 2 ;;
      --win-ip) WIN_IP="$2"; shift 2 ;;
      --bridge) BRIDGE_IF="$2"; shift 2 ;;
      --vm) VM_NAME="$2"; shift 2 ;;
      --skip-conflict-check) SKIP_CONFLICT=1; shift ;;
      -h|--help)
        echo "用法: mvb [选项]"
        echo "  --cidr <网段>           默认 192.168.200"
        echo "  --server-ip <IP>        默认 .131"
        echo "  --win-ip <IP>           默认 .2"
        echo "  --bridge <接口>         指定桥接接口"
        echo "  --vm <名称>             指定 Windows VM 名称"
        echo "  --skip-conflict-check   跳过冲突检测"
        exit 0
        ;;
      *) err "未知参数: $1"; exit 1 ;;
    esac
  done
}

detect_wifi_if() {
  if [ -n "$BRIDGE_IF" ]; then info "使用指定桥接接口: $BRIDGE_IF"; return; fi
  local ifc
  ifc=$(networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi|无线|AirPort/ {getline; print $NF; exit}')
  if [ -z "$ifc" ] && ifconfig en0 >/dev/null 2>&1; then ifc="en0"; fi
  BRIDGE_IF="${ifc:-en0}"
  if ! ifconfig "$BRIDGE_IF" >/dev/null 2>&1; then warn "接口 $BRIDGE_IF 不存在，回落 en0"; BRIDGE_IF="en0"; fi
  ok "Wi‑Fi 桥接接口: $BRIDGE_IF"
}

scan_images() {
  echo ""; echo "==== 镜像扫描 ===="; echo ""
  mapfile -t CAND < <(
    find "$ROOT" \( -name ".git" -o -name "logs" -o -name "ova_unpack" -o -name ".cache" \) -prune -o \
      -type f \( -iname "*.ova" -o -iname "*.ovf" -o -iname "*.vmx" \) -print 2>/dev/null |
    while read -r f; do ts=$(stat -f "%m" "$f" 2>/dev/null || echo 0); echo "$ts $f"; done |
    sort -rn | cut -d' ' -f2-
  )

  local SRC
  if [ "${#CAND[@]}" -eq 0 ]; then
    warn "未扫描到镜像。拖拽文件/目录到此窗口后回车："
    read -r SRC
  else
    echo "候选镜像（按修改时间）："
    local i=1; for c in "${CAND[@]}"; do echo "  $i) ${c/$ROOT\//}"; i=$((i+1)); done
    read -rp "选择序号（默认1），或拖拽路径覆盖: " sel
    if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "${#CAND[@]}" ]; then
      SRC="${CAND[$((sel-1))]}"
    elif [ -n "$sel" ]; then
      SRC="$sel"
    else
      SRC="${CAND[0]}"
    fi
  fi
  SRC="${SRC#"${SRC%%[![:space:]]*}"}"; SRC="${SRC%"${SRC##*[![:space:]]}"}"; SRC="${SRC//\'/}"
  [ -e "$SRC" ] || { err "路径不存在：$SRC"; exit 1; }
  IMAGE_SRC="$SRC"; ok "已选择：$IMAGE_SRC"; echo ""
}

convert_image() {
  local SRC_PATH="$1"; local OUT="$ROOT/server.qcow2"
  if [ -f "$OUT" ]; then
    warn "检测到 server.qcow2"; read -p "是否覆盖？[y/N] " y; [[ "$y" =~ ^[Yy]$ ]] && rm -f "$OUT" || { info "跳过转换"; return 0; }
  fi
  echo ""; echo "==== 镜像转换 ===="; echo ""
  local VMDK=""
  if [[ -d "$SRC_PATH" ]]; then
    local VMX; VMX="$(find "$SRC_PATH" -type d -mindepth 2 -prune -o -type f -iname "*.vmx" -print | head -n1)"
    [ -n "$VMX" ] || { err "目录内未找到 .vmx"; exit 1; }
    VMDK="$(awk -F'"' '/fileName.*\.vmdk/ {print $2; exit}' "$VMX")"; VMDK="$SRC_PATH/$VMDK"
  elif [[ "$SRC_PATH" == *.ova ]]; then
    local TMP="$ROOT/ova_unpack"; rm -rf "$TMP"; mkdir -p "$TMP"
    tar -xf "$SRC_PATH" -C "$TMP" 2>>"$LOG_DIR/convert.log"
    local OVF; OVF="$(find "$TMP" -type f -iname "*.ovf" | head -n1)"; [ -f "$OVF" ] || { err "OVA 内未找到 OVF"; exit 1; }
    VMDK="$(grep -Eo 'ovf:href="[^"]+\.vmdk"' "$OVF" | sed -E 's/.*href="([^"]+)".*/\1/' | head -n1)"; VMDK="$TMP/$VMDK"
  elif [[ "$SRC_PATH" == *.ovf ]]; then
    local DIR; DIR="$(dirname "$SRC_PATH")"
    VMDK="$(grep -Eo 'ovf:href="[^"]+\.vmdk"' "$SRC_PATH" | sed -E 's/.*href="([^"]+)".*/\1/' | head -n1)"; VMDK="$DIR/$VMDK"
  elif [[ "$SRC_PATH" == *.vmx ]]; then
    local DIR; DIR="$(dirname "$SRC_PATH")"
    VMDK="$(awk -F'"' '/fileName.*\.vmdk/ {print $2; exit}' "$SRC_PATH")"; VMDK="$DIR/$VMDK"
  else
    err "不支持的镜像格式：$SRC_PATH"
  fi
  [ -f "$VMDK" ] || { err "未找到 VMDK：$VMDK"; exit 1; }
  info "源磁盘：$VMDK"
  qemu-img convert -p -O qcow2 "$VMDK" "$OUT" 2>&1 | tee -a "$LOG_DIR/convert.log"
  [ -f "$OUT" ] || { err "转换失败，见 logs/convert.log"; exit 1; }
  ok "转换完成"; qemu-img info "$OUT" | head -n5; echo ""
  save_state "image_converted"
}

conflict_check() {
  [ "$SKIP_CONFLICT" -eq 1 ] && { info "跳过冲突检测"; return; }
  echo ""; echo "==== 网段冲突检测 ===="; echo ""
  info "检测 $CIDR_BASE.0/24（服务端 $SERVER_IP, Windows $WIN_IP）"
  local conflict=0
  ping -c1 -W1 "$SERVER_IP" >/dev/null 2>&1 && conflict=1 || true
  ping -c1 -W1 "$WIN_IP" >/dev/null 2>&1 && conflict=1 || true
  if [ "$conflict" -eq 1 ]; then
    warn "可能存在冲突（IP 有响应）"
    echo "A) 继续使用 $CIDR_BASE.0/24"
    echo "B) 切换到 192.168.201.0/24（201.131 / 201.2）"
    echo "C) 暂停排查"
    read -rp "[A/B/C] 默认A: " c; c=${c:-A}
    case "$c" in
      B|b) CIDR_BASE="192.168.201"; SERVER_IP="${CIDR_BASE}.131"; WIN_IP="${CIDR_BASE}.2"; ok "已切换：$SERVER_IP / $WIN_IP" ;;
      C|c) info "已暂停"; exit 0 ;;
      *) warn "继续使用默认网段" ;;
    esac
  else
    ok "未检测到明显冲突"
  fi
}

start_qemu() {
  local DISK="$1"; [ -f "$DISK" ] || { err "磁盘不存在：$DISK"; exit 1; }
  echo ""; echo "==== 启动 QEMU ===="; echo ""
  info "x86_64 (TCG)，4 vCPU / 4GB"
  local p=$SSH_PORT
  for i in $(seq 0 20); do
    if ! nc -z 127.0.0.1 "$p" >/dev/null 2>&1; then SSH_PORT=$p; break; fi
    p=$((p+1))
  done
  info "管理口 NAT 127.0.0.1:${SSH_PORT} → SSH；业务口桥接 $BRIDGE_IF"
  for i in 0 0 1 2 3 4 5 8 9 12 20 29 61 80 701 33 98 100 204 250 395 398 399 400seq 0 20); do
    if ! nc -z 127.0.0.1 "" >/dev/null 2>&1; then SSH_PORT=; break; fi
    p=0 0 1 2 3 4 5 8 9 12 20 29 61 80 701 33 98 100 204 250 395 398 399 400(p+1))
  done
  info "管理口 NAT 127.0.0.1: → SSH；业务口桥接 "
  warn "启动时需要 sudo（vmnet 桥接）"
  sudo qemu-system-x86_64 \
    -machine q35,accel=tcg -cpu max -smp 4 -m 4096 \
    -drive file="$DISK",format=qcow2,if=virtio,cache=writeback \
    -netdev user,id=mgmt,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22 \
    -device virtio-net-pci,netdev=mgmt,mac=52:54:00:22:33:45 \
    -netdev vmnet-bridged,id=biz,ifname="$BRIDGE_IF" \
    -device virtio-net-pci,netdev=biz,mac=52:54:00:22:33:44 \
    -vga virtio -display default \
    >"$LOG_DIR/qemu.log" 2>&1 &
  echo $! > "$PID_FILE"
  sleep 3
  ps -p "$(cat "$PID_FILE")" >/dev/null 2>&1 || { err "QEMU 启动失败（logs/qemu.log）"; exit 1; }
  ok "QEMU 已启动（PID: $(cat "$PID_FILE")）"
  save_state "qemu_started"
}

wait_ssh() {
  echo ""; echo "==== 等待 SSH ===="; echo -n "探测 127.0.0.1:2222"
  for _ in {1..60}; do
    if nc -z 127.0.0.1 "$SSH_PORT" >/dev/null 2>&1; then echo ""; ok "SSH 已开放"; return 0; fi
    echo -n "."; sleep 2
  done
  echo ""; warn "SSH 未就绪，请在控制台启用 sshd 后回车继续"
  read -p "" _
}

config_guest_network() {
  echo ""; echo "==== 配置服务端业务网卡 ===="; echo ""
  if ! nc -z 127.0.0.1 "$SSH_PORT" >/dev/null 2>&1; then
    warn "SSH 不可用，跳过自动配置"
    info "手动设置：$SERVER_IP/24（无网关）"
    return 0
  fi
  local user pass
  read -rp "来宾用户名（默认 root）: " user; user=${user:-root}
  read -rsp "来宾密码（默认 123456）: " pass; pass=${pass:-123456}; echo ""
  local script="
set -e
if command -v nmcli >/dev/null 2>&1; then
  IF=\$(nmcli -t -f DEVICE,STATE d | awk -F: '$2==\"connected\"{print $1}' | tail -n1)
  [ -n \"$IF\" ] || IF=\$(ip -o link show | awk -F: '$2!~/lo/{gsub(/ /,\"\",$2);print $2}' | tail -n1)
  CONN=\$(nmcli -t -f NAME,DEVICE con show | awk -F: -v dev=\"$IF\" '$2==dev{print $1; exit}')
  [ -n \"$CONN\" ] || CONN=\"$IF\"
  nmcli con mod \"$CONN\" ipv4.addresses $SERVER_IP/24 ipv4.method manual ipv4.gateway \"\" ipv4.dns \"\"
  nmcli con up \"$CONN\" || nmcli d reapply \"$IF\" || true
else
  IF=\$(ip -o link show | awk -F: '$2!~/lo/{gsub(/ /,\"\",$2);print $2}' | tail -n1)
  ip addr flush dev \"$IF\" 2>/dev/null || true
  ip addr add $SERVER_IP/24 dev \"$IF\"
  ip link set \"$IF\" up
fi
ip -4 addr; ip route
"
  expect > "$LOG_DIR/guest-net.log" 2>&1 <<EOF_EXP
set timeout 120
log_user 0
spawn ssh -p ${SSH_PORT} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${user}@127.0.0.1 "if command -v sudo >/dev/null 2>&1; then sudo bash -lc '$(printf "%q" "$script")'; else bash -lc '$(printf "%q" "$script")'; fi"
expect {
  -re "yes/no" { send "yes\r"; exp_continue }
  -re "[Pp]assword:" { send "$pass\r"; exp_continue }
  eof
}
EOF_EXP
  ok "已尝试设置服务端 IP：$SERVER_IP/24（无网关）"
  save_state "guest_configured"
}

config_windows() {
  echo ""; echo "==== 配置 Windows 虚拟机 ===="; echo ""
  prlctl list -a 2>/dev/null | grep -v "UUID" | awk '{print $NF}' || true
  if [ -z "$VM_NAME" ]; then read -rp "Windows VM 名称: " VM_NAME; fi
  prlctl list -a 2>/dev/null | grep -q "$VM_NAME" || { err "未找到 VM：$VM_NAME"; exit 1; }
  prlctl set "$VM_NAME" --device-add net --type shared --connect 2>/dev/null || true
  prlctl set "$VM_NAME" --device-add net --type bridged --iface "$BRIDGE_IF" --connect 2>/dev/null || true
  prlctl start "$VM_NAME" 2>/dev/null || true; sleep 5
  if prlctl exec "$VM_NAME" --cmd "powershell -Command \"Write-Host OK\"" >/dev/null 2>&1; then
    ok "检测到 Parallels Tools"
    prlctl copy "$VM_NAME" "$ROOT/windows/Config-BizNIC.ps1" "C:\\Users\\Public\\Config-BizNIC.ps1"
    prlctl exec "$VM_NAME" --cmd "powershell -ExecutionPolicy Bypass -File C:\\Users\\Public\\Config-BizNIC.ps1 -ServerIP $SERVER_IP -WindowsIP $WIN_IP" \
      2>&1 | tee "$LOG_DIR/windows.log"
  else
    warn "未检测到 Parallels Tools"
    echo "请在 Parallels 菜单：Actions → Install Parallels Tools"
    read -p "完成安装后输入 yes 继续: " yes
    if [[ "$yes" == "yes" ]]; then
      prlctl copy "$VM_NAME" "$ROOT/windows/Config-BizNIC.ps1" "C:\\Users\\Public\\Config-BizNIC.ps1"
      prlctl exec "$VM_NAME" --cmd "powershell -ExecutionPolicy Bypass -File C:\\Users\\Public\\Config-BizNIC.ps1 -ServerIP $SERVER_IP -WindowsIP $WIN_IP" \
        2>&1 | tee "$LOG_DIR/windows.log"
    else
      warn "已跳过自动配置。请在 Windows 内手动执行 C:\\Users\\Public\\Config-BizNIC.ps1"
    fi
  fi
  save_state "windows_configured"
}

health_check() {
  echo ""; echo "==== 健康检查 ===="; echo ""
  local S1="✗" S2="✗" S3="待测"
  if nc -z 127.0.0.1 "$SSH_PORT" >/dev/null 2>&1; then S1="✓"; ok "管理口 SSH 可达"; else err "管理口 SSH 不可达"; fi
  if ping -c2 -W2 "$SERVER_IP" >/dev/null 2>&1; then S2="✓"; ok "宿主 → 服务端($SERVER_IP) 可达"; else err "宿主 → 服务端 不通"; fi
  echo "请在 Windows 内执行：ping $SERVER_IP"; read -p "是否可达？[y/N] " y; [[ "$y" =~ ^[Yy]$ ]] && S3="✓" && ok "Windows → 服务端 可达" || { S3="✗"; warn "Windows → 服务端 不通"; }
  {
    echo "# Mac VM Bridge 健康检查报告"
    echo ""; echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')"; echo ""
    echo "## 配置摘要"
    echo "| 项目 | 值 |"; echo "|------|-----|"
    echo "| 桥接接口 | $BRIDGE_IF |"
    echo "| 业务网段 | $CIDR_BASE.0/24 |"
    echo "| 服务端 IP | $SERVER_IP |"
    echo "| Windows IP | $WIN_IP |"
    echo "| QEMU PID | $(cat "$PID_FILE" 2>/dev/null || echo "N/A") |"
    echo ""; echo "## 连通性测试"
    echo "| 测试项 | 状态 |"
    echo "|--------|------|"
    echo "| 管理口 SSH | $S1 |"
    echo "| 宿主 → 服务端 | $S2 |"
    echo "| Windows → 服务端 | $S3 |"
    echo ""; echo "## 日志"
    echo "- logs/convert.log"
    echo "- logs/qemu.log"
    echo "- logs/guest-net.log"
    echo "- logs/windows.log"
  } > "$REPORT_FILE"
  ok "报告已生成：report.md"
}

main() {
  parse_args "$@"
  echo ""; echo "╔══════════════════════════════════════╗"
  echo "║     Mac VM Bridge - 自动化向导      ║"
  echo "╚══════════════════════════════════════╝"; echo ""
  local stage; stage=$(load_state)
  if [ "$stage" != "init" ]; then info "检测到上次状态：$stage"; read -p "从断点继续？[y/N] " r; [[ "$r" =~ ^[Yy]$ ]] || { save_state "init"; stage="init"; }; fi
  detect_wifi_if
  if [ "$stage" == "init" ]; then scan_images; convert_image "$IMAGE_SRC"; fi
  if [ "$stage" == "init" ] || [ "$stage" == "image_converted" ]; then conflict_check; start_qemu "$ROOT/server.qcow2"; fi
  if [ "$stage" == "init" ] || [ "$stage" == "image_converted" ] || [ "$stage" == "qemu_started" ]; then wait_ssh; config_guest_network; fi
  if [ "$stage" != "windows_configured" ]; then config_windows; fi
  health_check
  echo ""; ok "完成。查看 report.md；清理：./scripts/cleanup.sh"; echo ""
}

main "$@"
