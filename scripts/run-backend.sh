#!/bin/zsh
set -euo pipefail

source "$HOME/Library/Application Support/WIMC/admin.env"

cd "$HOME/dev/wimc"
exec "$HOME/dev/wimc/backend/.venv/bin/uvicorn" backend.app.main:app --host 127.0.0.1 --port 8011
