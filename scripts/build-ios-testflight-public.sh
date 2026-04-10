#!/bin/zsh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PUBLIC_BASE_URL="${PUBLIC_BASE_URL:-https://cartly-api.seoa-nas.com}"
APP_CONFIG_BASE_URL="${APP_CONFIG_BASE_URL:-$PUBLIC_BASE_URL}"

cd "$REPO_ROOT"

flutter build ipa \
  --release \
  --dart-define=CARTLY_REMOTE_BASE_URL="$PUBLIC_BASE_URL" \
  --dart-define=CARTLY_APP_CONFIG_BASE_URL="$APP_CONFIG_BASE_URL"
