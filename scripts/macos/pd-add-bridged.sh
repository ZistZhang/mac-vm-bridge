#!/usr/bin/env bash
set -euo pipefail
VM="${1:-}"
IF="${2:-en0}"

command -v prlctl >/dev/null 2>&1 || { echo "[X] prlctl not found. Install Parallels Desktop." >&2; exit 1; }

get_names() {
  if prlctl list -a -o name >/dev/null 2>&1; then
    prlctl list -a -o name | awk 'NR>1{print $0}'
  else
    prlctl list -a | awk 'NR>1{print substr($0,index($0,$4))}'
  fi
}

get_running() {
  if prlctl list -a -o name,status >/dev/null 2>&1; then
    prlctl list -a -o name,status | awk 'NR>1 && $2=="running"{print $1}'
  else
    prlctl list -a | awk 'NR>1 && $2=="running"{print substr($0,index($0,$4))}'
  fi
}

auto_detect_vm() {
  # Prefer running Windows VM
  local pick=""
  while read -r n; do
    if prlctl list -i "$n" 2>/dev/null | grep -qiE 'OS:.*Windows|Guest OS:.*Windows|win-'; then pick="$n"; break; fi
  done < <(get_running || true)
  if [ -n "$pick" ]; then echo "$pick"; return 0; fi
  # Then any Windows VM
  while read -r n; do
    if prlctl list -i "$n" 2>/dev/null | grep -qiE 'OS:.*Windows|Guest OS:.*Windows|win-'; then pick="$n"; break; fi
  done < <(get_names || true)
  if [ -n "$pick" ]; then echo "$pick"; return 0; fi
  # If single VM exists, pick it
  local cnt=0 only=""
  while read -r n; do cnt=$((cnt+1)); only="$n"; done < <(get_names || true)
  if [ "$cnt" -eq 1 ]; then echo "$only"; return 0; fi
  return 1
}

if [ -z "$VM" ]; then
  if VM=$(auto_detect_vm); then
    echo "[i] Auto-detected VM: $VM"
  else
    echo "[X] Could not auto-detect Windows VM. Usage: $0 <VM_NAME> [bridge_if]" >&2
    exit 2
  fi
fi

# Existence check
if prlctl list -a -o name >/dev/null 2>&1; then
  prlctl list -a -o name | awk 'NR>1{print $0}' | grep -F " $VM" >/dev/null || { echo "[X] VM $VM not found." >&2; exit 2; }
fi

# Ensure one Shared and one Bridged
if ! prlctl list "$VM" -i | grep -q "type=shared"; then
  prlctl set "$VM" --device-add net --type shared --connect || true
fi
if ! prlctl list "$VM" -i | grep -q "type=bridged"; then
  prlctl set "$VM" --device-add net --type bridged --iface "$IF" --connect || true
else
  prlctl set "$VM" --device-set net --type bridged --iface "$IF" --connect || true
fi

echo "[+] $VM now has Shared + Bridged($IF)."
