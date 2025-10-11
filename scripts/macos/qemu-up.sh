#!/usr/bin/env bash
set -euo pipefail

# Env: DISK, BR_IF (default en0), MEM (4G), SMP (4), SSH_PORT (2222)
DISK=${DISK:?"Set DISK to qcow2 path"}
BR_IF=${BR_IF:-en0}
MEM=${MEM:-4G}
SMP=${SMP:-4}
SSH_PORT=${SSH_PORT:-2222}
QEMU_BIN=${QEMU_BIN:-qemu-system-x86_64}

# Avoid port conflict by probing and incrementing
probe_port() {
  local p=$1
  while lsof -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1; do p=$((p+1)); done
  echo "$p"
}
SSH_PORT=$(probe_port "$SSH_PORT")

export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
sudo --preserve-env=OBJC_DISABLE_INITIALIZE_FORK_SAFETY \
  "$QEMU_BIN" \
  -accel tcg,thread=multi -cpu max -smp "$SMP" -m "$MEM" \
  -drive file="$DISK",format=qcow2,if=virtio,cache=writeback \
  -netdev user,id=mgmt,hostfwd=tcp:127.0.0.1:"$SSH_PORT"-:22 \
  -device virtio-net-pci,netdev=mgmt,mac=52:54:00:22:33:45 \
  -netdev vmnet-bridged,id=biz,ifname="$BR_IF" \
  -device virtio-net-pci,netdev=biz,mac=52:54:00:22:33:44 \
  -vga virtio -display default,show-cursor=on \
  -daemonize -pidfile vm.pid -qmp unix:qmp.sock,server,nowait \
  -D qemu.log -msg timestamp=on

echo "[+] QEMU started. SSH: 127.0.0.1:$SSH_PORT; QMP: qmp.sock; PID: $(cat vm.pid)"
