#!/bin/zsh
set -euo pipefail

source "$HOME/Library/Application Support/WIMC/admin.env"

cd "$HOME/dev/wimc/admin-web"
exec npm run start
