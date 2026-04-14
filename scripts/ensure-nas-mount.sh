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

STORAGE_ROOT="${CARTLY_STORAGE_ROOT:-${STORAGE_ROOT:-/Volumes/AI/WIMC}}"
NAS_MOUNT_POINT="${CARTLY_NAS_MOUNT_POINT:-${STORAGE_ROOT:h}}"
NAS_SHARE="${CARTLY_NAS_SHARE:-${NAS_MOUNT_POINT:t}}"
NAS_HOST="${CARTLY_NAS_HOST:-192.168.68.67}"
NAS_USER="${CARTLY_NAS_USER:-jmsd}"
MOUNT_URL="smb://${NAS_USER}@${NAS_HOST}/${NAS_SHARE}"

log() {
  echo "[Cartly NAS] $*"
}

is_mount_ready() {
  /sbin/mount | /usr/bin/grep -F " on ${NAS_MOUNT_POINT} (" >/dev/null 2>&1 && [[ -d "$NAS_MOUNT_POINT" ]]
}

wait_for_mount() {
  local max_seconds="${1:-15}"
  for _ in $(seq 1 "$max_seconds"); do
    if is_mount_ready; then
      return 0
    fi
    /bin/sleep 1
  done
  return 1
}

if is_mount_ready; then
  log "already mounted at ${NAS_MOUNT_POINT}"
else
  log "mount missing, trying ${MOUNT_URL}"
  mount_result=$(osascript \
    -e 'try' \
    -e "set mountedVol to mount volume \"${MOUNT_URL}\"" \
    -e 'return mountedVol as text' \
    -e 'on error errMsg number errNum' \
    -e 'return "ERROR:" & errNum & ":" & errMsg' \
    -e 'end try' 2>&1 || true)
  log "mount result: ${mount_result}"

  if ! wait_for_mount 15; then
    log "mount did not appear at ${NAS_MOUNT_POINT}"
    log "manual fallback: open Finder and connect to ${MOUNT_URL}"
    exit 1
  fi
fi

if [[ ! -d "$STORAGE_ROOT" ]]; then
  log "mount is present but storage root is missing: ${STORAGE_ROOT}"
  exit 1
fi

if ! /bin/ls "$STORAGE_ROOT" >/dev/null 2>&1; then
  log "mount is present but storage root is not readable: ${STORAGE_ROOT}"
  exit 1
fi

log "ready: mount=${NAS_MOUNT_POINT} storage=${STORAGE_ROOT}"
