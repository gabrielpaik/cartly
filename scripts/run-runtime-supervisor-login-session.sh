#!/bin/zsh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-/opt/homebrew/bin/python3.12}"
exec "$PYTHON_BIN" "$REPO_ROOT/scripts/runtime_supervisor.py"
