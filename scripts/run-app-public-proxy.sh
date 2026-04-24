#!/bin/zsh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -f "$HOME/Library/Application Support/Cartly/admin.env" ]]; then
  source "$HOME/Library/Application Support/Cartly/admin.env"
fi

export APP_PUBLIC_PROXY_PORT="${APP_PUBLIC_PROXY_PORT:-3100}"
export APP_PUBLIC_PROXY_HOST="${APP_PUBLIC_PROXY_HOST:-127.0.0.1}"
export APP_PUBLIC_PROXY_BACKEND_BASE="${APP_PUBLIC_PROXY_BACKEND_BASE:-${CARTLY_API_BASE:-http://127.0.0.1:8011}}"

NODE_BIN="${NODE_BIN:-/opt/homebrew/bin/node}"
if [[ ! -x "$NODE_BIN" ]]; then
  echo "[app-public-proxy] node not found at $NODE_BIN" >&2
  exit 127
fi

cd "$REPO_ROOT"
exec "$NODE_BIN" "$REPO_ROOT/scripts/app_public_proxy.mjs"
