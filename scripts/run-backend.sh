#!/bin/zsh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SAFE_PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH="$SAFE_PATH:${PATH:-}"

if [[ -f "$HOME/Library/Application Support/Cartly/admin.env" ]]; then
  source "$HOME/Library/Application Support/Cartly/admin.env"
elif [[ -f "$HOME/Library/Application Support/WIMC/admin.env" ]]; then
  source "$HOME/Library/Application Support/WIMC/admin.env"
fi
export PATH="$SAFE_PATH:${PATH:-}"

cd "$REPO_ROOT"
exec "$REPO_ROOT/backend/.venv/bin/uvicorn" backend.app.main:app --host 127.0.0.1 --port 8011
