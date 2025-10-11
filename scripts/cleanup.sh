#!/usr/bin/env bash
set -euo pipefail

GREEN="\033[32m"; YELL="\033[33m"; NC="\033[0m"
ok(){ echo -e "${GREEN}✓${NC} $*"; }
warn(){ echo -e "${YELL}⚠${NC} $*"; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_FILE="$ROOT/qemu.pid"
STATE_FILE="$ROOT/state.json"

FULL=${1:-}

echo ""; echo "==== 清理 ===="; echo ""

if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE")
  if ps -p "$PID" >/dev/null 2>&1; then
    echo "停止 QEMU (PID: $PID)..."
    sudo kill -TERM "$PID" 2>/dev/null || true
    sleep 2
    ps -p "$PID" >/dev/null 2>&1 && sudo kill -KILL "$PID" 2>/dev/null || true
    ok "QEMU 已停止"
  else
    warn "QEMU 已不在运行"
  fi
  rm -f "$PID_FILE"
else
  warn "未发现 PID 文件"
fi

rm -rf "$ROOT/ova_unpack" 2>/dev/null || true

if [ "$FULL" = "--full" ]; then
  warn "完全清理：删除 qcow2、日志、状态、报告"
  rm -f "$ROOT/server.qcow2" "$STATE_FILE" "$ROOT/report.md"
  rm -rf "$ROOT/logs"
else
  echo "保留：server.qcow2、logs/"
fi

ok "清理完成"
