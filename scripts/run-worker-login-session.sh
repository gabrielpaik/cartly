#!/bin/zsh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SAFE_PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
LOG_DIR="$HOME/Library/Logs/Cartly"
mkdir -p "$LOG_DIR"
exec >> "$LOG_DIR/worker-login-session.log" 2>&1

export PATH="$SAFE_PATH:${PATH:-}"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] worker launcher start"
echo "HOME=$HOME"
echo "PWD=$(pwd)"

if [[ -f "$HOME/Library/Application Support/Cartly/admin.env" ]]; then
  source "$HOME/Library/Application Support/Cartly/admin.env"
elif [[ -f "$HOME/Library/Application Support/WIMC/admin.env" ]]; then
  source "$HOME/Library/Application Support/WIMC/admin.env"
fi
export PATH="$SAFE_PATH:${PATH:-}"

cd "$REPO_ROOT"
echo "cwd=$(pwd)"

if pgrep -f 'backend/worker_daemon.py' >/dev/null 2>&1; then
  echo "[Cartly] worker daemon already running"
  exit 0
fi

echo "[Cartly] starting worker daemon in login-session context"
exec "$REPO_ROOT/backend/.venv/bin/python" "$REPO_ROOT/backend/worker_daemon.py"
