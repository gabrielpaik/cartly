#!/bin/zsh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SAFE_PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
LOG_DIR="$HOME/Library/Logs/Cartly"
mkdir -p "$LOG_DIR"
exec >> "$LOG_DIR/admin-web.log" 2>&1

export PATH="$SAFE_PATH:${PATH:-}"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] admin-web launcher start"
echo "HOME=$HOME"
echo "PWD=$(pwd)"

if [[ -f "$HOME/Library/Application Support/Cartly/admin.env" ]]; then
  source "$HOME/Library/Application Support/Cartly/admin.env"
fi
export PATH="$SAFE_PATH:${PATH:-}"

cd "$REPO_ROOT/admin-web"
echo "cwd=$(pwd)"

if lsof -iTCP:3000 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "[Cartly] admin-web already listening on :3000"
  exit 0
fi

echo "[Cartly] starting admin-web on :3000"
exec npm run start
