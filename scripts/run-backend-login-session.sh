#!/bin/zsh
set -euo pipefail

LOG_DIR="$HOME/Library/Logs/WIMC"
mkdir -p "$LOG_DIR"
exec >> "$LOG_DIR/backend-login-session.log" 2>&1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] launcher start"
echo "HOME=$HOME"
echo "PWD=$(pwd)"

source "$HOME/Library/Application Support/WIMC/admin.env"

echo "ADMIN_TOKEN_SET=${ADMIN_TOKEN:+yes}"

cd "$HOME/dev/wimc"
echo "cwd=$(pwd)"

if lsof -iTCP:8011 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "[WIMC] backend already listening on :8011"
  exit 0
fi

echo "[WIMC] starting backend in login-session context"
exec "$HOME/dev/wimc/backend/.venv/bin/uvicorn" backend.app.main:app --host 127.0.0.1 --port 8011
