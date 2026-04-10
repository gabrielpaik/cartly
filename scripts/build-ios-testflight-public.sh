#!/bin/zsh
set -euo pipefail

PUBLIC_BASE_URL="${PUBLIC_BASE_URL:-https://scancart-api.seoa-nas.com}"
APP_CONFIG_BASE_URL="${APP_CONFIG_BASE_URL:-$PUBLIC_BASE_URL}"

cd "$HOME/dev/wimc"

flutter build ipa \
  --release \
  --dart-define=WIMC_REMOTE_BASE_URL="$PUBLIC_BASE_URL" \
  --dart-define=WIMC_APP_CONFIG_BASE_URL="$APP_CONFIG_BASE_URL"
