#!/usr/bin/env bash
set -euo pipefail

GREEN="\033[32m"; YELL="\033[33m"; RED="\033[31m"; NC="\033[0m"
ok(){ echo -e "${GREEN}✓${NC} $*"; }
warn(){ echo -e "${YELL}⚠${NC} $*"; }
err(){ echo -e "${RED}✗${NC} $*"; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs"; mkdir -p "$LOG_DIR"

echo "======================================"
echo " Mac VM Bridge - 依赖安装与环境准备"
echo "======================================"
echo ""

# 1) Xcode CLT
if ! xcode-select -p >/dev/null 2>&1; then
  warn "安装 Xcode Command Line Tools..."
  xcode-select --install || true
  read -p "完成安装后按回车继续..." _
fi
ok "Xcode CLT 就绪"

# 2) Homebrew
if ! command -v brew >/dev/null 2>&1; then
  warn "未检测到 Homebrew，正在安装..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
  export PATH="/opt/homebrew/bin:$PATH"
elif [ -x /usr/local/bin/brew ]; then
  eval "$([ -x /usr/local/bin/brew ] && /usr/local/bin/brew shellenv)"
fi

command -v brew >/dev/null 2>&1 || { err "Homebrew 安装失败"; exit 1; }
ok "Homebrew 就绪"

# 3) 安装依赖
export HOMEBREW_NO_ANALYTICS=1
pkgs=(qemu jq expect gnu-sed coreutils)
for p in "${pkgs[@]}"; do
  if ! brew list --versions "$p" >/dev/null 2>&1; then
    echo "安装 $p ..."
    brew install "$p" >>"$LOG_DIR/bootstrap.log" 2>&1
  fi
done

export PATH="/opt/homebrew/opt/gnu-sed/libexec/gnubin:$PATH"
export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
ok "依赖安装完成"

# 4) QEMU vmnet 检测
if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
  err "qemu-system-x86_64 不存在"
  exit 1
fi
QEMU_VER=$(qemu-system-x86_64 --version | head -n1)
ok "QEMU: $QEMU_VER"

if qemu-system-x86_64 -netdev help 2>&1 | grep -q 'vmnet-bridged'; then
  ok "QEMU 支持 vmnet-bridged"
else
  warn "未检测到 vmnet-bridged，尝试升级..."
  brew upgrade qemu >>"$LOG_DIR/bootstrap.log" 2>&1 || true
  if ! qemu-system-x86_64 -netdev help 2>&1 | grep -q 'vmnet-bridged'; then
    warn "仍未检测到 vmnet-bridged。Wi‑Fi 桥接可能受限（需 sudo），建议准备 USB 有线网卡。"
  else
    ok "已支持 vmnet-bridged"
  fi
fi

# 5) Parallels CLI
if ! command -v prlctl >/dev/null 2>&1; then
  err "未检测到 prlctl，请安装并启动一次 Parallels Desktop"
  exit 1
fi
ok "Parallels CLI 就绪：$(prlctl --version | head -n1)"

echo ""
echo "======================================"
ok "环境准备完成"
echo "======================================"
