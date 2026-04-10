#!/bin/zsh
set -euo pipefail

source "$HOME/Library/Application Support/WIMC/admin.env"

export APP_PUBLIC_PROXY_PORT="${APP_PUBLIC_PROXY_PORT:-3100}"
export APP_PUBLIC_PROXY_HOST="${APP_PUBLIC_PROXY_HOST:-127.0.0.1}"
export APP_PUBLIC_PROXY_BACKEND_BASE="${APP_PUBLIC_PROXY_BACKEND_BASE:-${WIMC_API_BASE:-http://127.0.0.1:8011}}"

NODE_BIN="${NODE_BIN:-/opt/homebrew/bin/node}"
if [[ ! -x "$NODE_BIN" ]]; then
  echo "[app-public-proxy] node not found at $NODE_BIN" >&2
  exit 127
fi

cd "$HOME/dev/wimc"
exec "$NODE_BIN" "$HOME/dev/wimc/scripts/app_public_proxy.mjs"
