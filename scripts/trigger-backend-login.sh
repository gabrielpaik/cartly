#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMAND_PATH="$SCRIPT_DIR/Cartly Backend.command"
LOG_DIR="$HOME/Library/Logs/Cartly"
LOG_FILE="$LOG_DIR/backend-login-trigger.log"

mkdir -p "$LOG_DIR"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

{
  echo "[$(timestamp)] trigger start"
  echo "HOME=$HOME"
  echo "PWD=$(pwd)"
  echo "COMMAND_PATH=$COMMAND_PATH"

  if pgrep -f 'runtime_supervisor.py' >/dev/null 2>&1; then
    echo "[trigger] supervisor already running"
    exit 0
  fi

  delay="${CARTLY_LOGIN_TRIGGER_DELAY_SECONDS:-8}"
  echo "[trigger] delay=${delay}s"
  sleep "$delay"

  if pgrep -f 'runtime_supervisor.py' >/dev/null 2>&1; then
    echo "[trigger] supervisor appeared during delay"
    exit 0
  fi

  echo "[trigger] opening Terminal for $COMMAND_PATH"
  /usr/bin/open -g -a Terminal "$COMMAND_PATH"
  echo "[trigger] open requested"
} >> "$LOG_FILE" 2>&1
