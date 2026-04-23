#!/bin/zsh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-$REPO_ROOT/backend/.venv/bin/python}"
LOG_DIR="$HOME/Library/Logs/Cartly"
LOG_FILE="$LOG_DIR/worker-login-session.log"
SAFE_PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
RESTART_DELAY_SECONDS="${CARTLY_WORKER_RESTART_DELAY_SECONDS:-2}"

mkdir -p "$LOG_DIR"
exec >>"$LOG_FILE" 2>&1

export PATH="$SAFE_PATH"

if [ -f "$REPO_ROOT/admin.env" ]; then
  set -a
  source "$REPO_ROOT/admin.env"
  set +a
fi

export PYTHONUNBUFFERED=1
export PYTHONIOENCODING="utf-8"

cd "$REPO_ROOT"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] worker launcher start"
echo "HOME=$HOME"
echo "PWD=$PWD"
echo "cwd=$REPO_ROOT"

while true; do
  if /usr/bin/pgrep -f 'backend/worker_daemon.py' >/dev/null 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] worker daemon already running, launcher exits"
    exit 0
  fi

  "$REPO_ROOT/scripts/ensure-nas-mount.sh"

  echo "[Cartly] starting worker daemon in login-session context"
  set +e
  "$PYTHON_BIN" "$REPO_ROOT/backend/worker_daemon.py"
  exit_code=$?
  set -e
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] worker daemon exited code=$exit_code"

  if [ "$exit_code" -eq 0 ]; then
    exit 0
  fi

  sleep "$RESTART_DELAY_SECONDS"
done
