#!/usr/bin/env bash
set -euo pipefail

# Detect qemu-system-x86_64 and vmnet support
qemu_bin="${QEMU_BIN:-$(command -v qemu-system-x86_64 || true)}"
if [[ -z "$qemu_bin" ]]; then
  echo "[X] qemu-system-x86_64 not found. Install via Homebrew: brew install qemu" >&2
  exit 1
fi

echo "[+] qemu: $qemu_bin"
if "${qemu_bin}" -netdev help 2>&1 | grep -q 'vmnet-bridged'; then
  echo "[+] vmnet-bridged supported"
else
  echo "[X] vmnet-bridged not supported by this QEMU. Consider upgrading QEMU or using a build with vmnet." >&2
  exit 2
fi

# List likely Wi‑Fi interfaces
if command -v networksetup >/dev/null 2>&1; then
  echo "[i] Network Services:"; networksetup -listallhardwareports | awk 'BEGIN{w=0} /Hardware Port: Wi-Fi/{w=1} w{print} /^$/{w=0}' || true
fi

echo "[i] Suggest using your Wi‑Fi interface (often en0) as bridge ifname."
