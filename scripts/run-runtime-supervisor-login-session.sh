#!/bin/zsh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec /usr/bin/python3 "$REPO_ROOT/scripts/runtime_supervisor.py"
