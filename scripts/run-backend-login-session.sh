#!/bin/zsh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$HOME/Library/Logs/Cartly"
mkdir -p "$LOG_DIR"
exec >> "$LOG_DIR/backend-login-session.log" 2>&1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] launcher start"
echo "HOME=$HOME"
echo "PWD=$(pwd)"

if [[ -f "$HOME/Library/Application Support/Cartly/admin.env" ]]; then
  source "$HOME/Library/Application Support/Cartly/admin.env"
elif [[ -f "$HOME/Library/Application Support/WIMC/admin.env" ]]; then
  source "$HOME/Library/Application Support/WIMC/admin.env"
fi

echo "ADMIN_TOKEN_SET=${ADMIN_TOKEN:+yes}"

cd "$REPO_ROOT"
echo "cwd=$(pwd)"

if lsof -iTCP:8011 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "[Cartly] backend already listening on :8011"
  exit 0
fi

echo "[Cartly] starting backend in login-session context"
exec "$REPO_ROOT/backend/.venv/bin/uvicorn" backend.app.main:app --host 127.0.0.1 --port 8011
