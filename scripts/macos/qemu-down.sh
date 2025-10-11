#!/usr/bin/env bash
set -euo pipefail

if [[ -S qmp.sock ]]; then
  printf '{"execute":"qmp_capabilities"}\n{"execute":"system_powerdown"}\n' | socat - UNIX-CONNECT:qmp.sock || true
  for i in $(seq 1 20); do
    if [[ -f vm.pid ]] && ! kill -0 "$(cat vm.pid)" 2>/dev/null; then
      echo "[+] Stopped"
      rm -f vm.pid qmp.sock
      exit 0
    fi
    sleep 1
  done
fi
if [[ -f vm.pid ]]; then
  kill "$(cat vm.pid)" || true
  rm -f vm.pid
fi
rm -f qmp.sock || true
