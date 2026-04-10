#!/bin/zsh
set -euo pipefail

LOG_DIR="$HOME/Library/Logs/WIMC"
mkdir -p "$LOG_DIR"
exec >> "$LOG_DIR/worker-login-session.log" 2>&1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] worker launcher start"
echo "HOME=$HOME"
echo "PWD=$(pwd)"

source "$HOME/Library/Application Support/WIMC/admin.env"

cd "$HOME/dev/wimc"
echo "cwd=$(pwd)"

if pgrep -f 'backend/worker_daemon.py' >/dev/null 2>&1; then
  echo "[WIMC] worker daemon already running"
  exit 0
fi

echo "[WIMC] starting worker daemon in login-session context"
exec "$HOME/dev/wimc/backend/.venv/bin/python" "$HOME/dev/wimc/backend/worker_daemon.py"
