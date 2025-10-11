#!/usr/bin/env bash
set -euo pipefail
VM="${1:-WinClient}"
IF="${2:-en0}"

command -v prlctl >/dev/null 2>&1 || { echo "[X] prlctl not found. Install Parallels Desktop." >&2; exit 1; }

prlctl list -a | grep -F "$VM" >/dev/null || { echo "[X] VM $VM not found (prlctl list -a)." >&2; exit 2; }

# Ensure one Shared and one Bridged
if ! prlctl list "$VM" -i | grep -q "type=shared"; then
  prlctl set "$VM" --device-add net --type shared --connect
fi
if ! prlctl list "$VM" -i | grep -q "type=bridged"; then
  prlctl set "$VM" --device-add net --type bridged --iface "$IF" --connect
else
  # Ensure bridged uses desired iface when possible
  prlctl set "$VM" --device-set net --type bridged --iface "$IF" --connect || true
fi

echo "[+] $VM now has Shared + Bridged($IF)."
