#!/bin/zsh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SAFE_PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
LOG_DIR="$HOME/Library/Logs/Cartly"
RUN_LOG="$LOG_DIR/runtime-refresh.log"
mkdir -p "$LOG_DIR"
exec >> "$RUN_LOG" 2>&1
export PATH="$SAFE_PATH:${PATH:-}"

WITH_PREVIEW=0
SKIP_ADMIN_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --with-preview)
      WITH_PREVIEW=1
      ;;
    --skip-admin-build)
      SKIP_ADMIN_BUILD=1
      ;;
    *)
      echo "unknown argument: $arg"
      echo "usage: $0 [--with-preview] [--skip-admin-build]"
      exit 1
      ;;
  esac
done

if [[ -f "$HOME/Library/Application Support/Cartly/admin.env" ]]; then
  source "$HOME/Library/Application Support/Cartly/admin.env"
fi
export PATH="$SAFE_PATH:${PATH:-}"

if [[ -z "${ADMIN_TOKEN:-}" ]]; then
  echo "ADMIN_TOKEN is missing"
  exit 1
fi

BACKEND_URL="http://127.0.0.1:8011"
ADMIN_URL="http://127.0.0.1:3000"
COOKIE_JAR=$(mktemp)
TMP_DIR=$(mktemp -d)
cleanup() {
  /bin/rm -f "$COOKIE_JAR"
  /bin/rm -rf "$TMP_DIR"
}
trap cleanup EXIT

stop_listener() {
  local port="$1"
  local label="$2"
  local pids
  pids=$((/usr/sbin/lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true) | tr '\n' ' ' | sed 's/[[:space:]]*$//')
  if [[ -z "$pids" ]]; then
    echo "[$label] nothing listening on :$port"
    return 0
  fi

  echo "[$label] stopping listener on :$port ($pids)"
  kill $pids 2>/dev/null || true
  for _ in {1..20}; do
    if ! /usr/sbin/lsof -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
      echo "[$label] listener on :$port stopped"
      return 0
    fi
    /bin/sleep 0.5
  done

  pids=$((/usr/sbin/lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true) | tr '\n' ' ' | sed 's/[[:space:]]*$//')
  if [[ -n "$pids" ]]; then
    echo "[$label] force-killing listener on :$port ($pids)"
    kill -9 $pids 2>/dev/null || true
  fi
}

wait_for_http() {
  local url="$1"
  local label="$2"
  local max_seconds="${3:-60}"

  for _ in $(seq 1 "$max_seconds"); do
    if /usr/bin/curl -fsS "$url" >/dev/null 2>&1; then
      echo "[$label] ready: $url"
      return 0
    fi
    /bin/sleep 1
  done

  echo "[$label] timeout waiting for $url"
  return 1
}

stop_process_match() {
  local pattern="$1"
  local label="$2"
  local pids
  pids=$((/usr/bin/pgrep -f "$pattern" 2>/dev/null || true) | tr '\n' ' ' | sed 's/[[:space:]]*$//')
  if [[ -z "$pids" ]]; then
    echo "[$label] no matching process"
    return 0
  fi

  echo "[$label] stopping process ($pids)"
  kill $pids 2>/dev/null || true
  for _ in {1..20}; do
    if ! /usr/bin/pgrep -f "$pattern" >/dev/null 2>&1; then
      echo "[$label] process stopped"
      return 0
    fi
    /bin/sleep 0.5
  done

  pids=$((/usr/bin/pgrep -f "$pattern" 2>/dev/null || true) | tr '\n' ' ' | sed 's/[[:space:]]*$//')
  if [[ -n "$pids" ]]; then
    echo "[$label] force-killing process ($pids)"
    kill -9 $pids 2>/dev/null || true
  fi
}

wait_for_process() {
  local pattern="$1"
  local label="$2"
  local max_seconds="${3:-30}"

  for _ in $(seq 1 "$max_seconds"); do
    if /usr/bin/pgrep -f "$pattern" >/dev/null 2>&1; then
      echo "[$label] ready: $pattern"
      return 0
    fi
    /bin/sleep 1
  done

  echo "[$label] timeout waiting for process $pattern"
  return 1
}

echo "[$(/bin/date '+%Y-%m-%d %H:%M:%S')] runtime refresh start"
echo "repo=$REPO_ROOT"
echo "with_preview=$WITH_PREVIEW skip_admin_build=$SKIP_ADMIN_BUILD"

if [[ "$WITH_PREVIEW" == "1" ]]; then
  echo "[preview] rebuilding app preview"
  "$REPO_ROOT/scripts/build-admin-app-preview.sh"
fi

if [[ "$SKIP_ADMIN_BUILD" != "1" ]]; then
  echo "[admin-web] building latest release bundle"
  (
    cd "$REPO_ROOT/admin-web"
    npm run build
  )
fi

if ! "$REPO_ROOT/scripts/ensure-nas-mount.sh"; then
  echo "[preflight] NAS mount is unavailable, refresh aborted before stopping runtime"
  exit 1
fi

stop_process_match "runtime_supervisor.py" runtime-supervisor
stop_process_match "run-runtime-supervisor-login-session.sh" runtime-supervisor-shell
stop_process_match "run-backend-once-login-session.sh" backend-launcher
stop_process_match "run-worker-login-session.sh" worker-launcher
stop_listener 3000 admin-web
stop_listener 8011 backend
stop_process_match "worker_daemon.py" worker

echo "[runtime-supervisor] starting latest process"
SUPERVISOR_PID=$(/usr/bin/python3 "$REPO_ROOT/scripts/spawn_detached.py" "$REPO_ROOT/scripts/run-backend-login-session.sh" "$REPO_ROOT")
echo "[runtime-supervisor] detached pid=$SUPERVISOR_PID"

echo "[admin-web] starting latest process"
ADMIN_PID=$(/usr/bin/python3 "$REPO_ROOT/scripts/spawn_detached.py" "$REPO_ROOT/scripts/run-admin-web.sh" "$REPO_ROOT/admin-web")
echo "[admin-web] detached pid=$ADMIN_PID"

wait_for_process "runtime_supervisor.py" runtime-supervisor 30
wait_for_http "$BACKEND_URL/health" backend 60
wait_for_http "$ADMIN_URL/login" admin-web 60
wait_for_process "worker_daemon.py" worker 30

/usr/bin/curl -fsS "$BACKEND_URL/health" > "$TMP_DIR/health.json"
/usr/bin/python3 - <<'PY' "$TMP_DIR/health.json"
import json,sys
payload=json.load(open(sys.argv[1]))
assert payload.get('ok') is True
assert payload.get('storageWritable') is True
print(f"[smoke] health ok service={payload.get('service')} storageRoot={payload.get('storageRoot')}")
PY

/usr/bin/curl -fsS "$BACKEND_URL/v1/app-config" > "$TMP_DIR/app-config.json"
/usr/bin/python3 - <<'PY' "$TMP_DIR/app-config.json"
import json,sys
payload=json.load(open(sys.argv[1]))
assert payload.get('ok') is True
print(f"[smoke] app-config ok adSlots={len(payload['data'].get('adSlots', []))} logoText={payload['data']['branding'].get('logoText')}")
PY

/usr/bin/curl -fsS -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
  -X POST "$ADMIN_URL/api/admin-auth/login" \
  -H 'Content-Type: application/json' \
  --data "{\"password\":\"$ADMIN_TOKEN\"}" > "$TMP_DIR/admin-login.json"
/usr/bin/python3 - <<'PY' "$TMP_DIR/admin-login.json"
import json,sys
payload=json.load(open(sys.argv[1]))
assert payload.get('ok') is True
print('[smoke] admin login ok')
PY

for path in \
  "$ADMIN_URL/api/cartly-admin/admin/dashboard/summary" \
  "$ADMIN_URL/api/cartly-admin/admin/ads/slots" \
  "$ADMIN_URL/api/cartly-admin/admin/config"
do
  /usr/bin/curl -fsS -b "$COOKIE_JAR" "$path" >/dev/null
  echo "[smoke] ok $path"
done

if /usr/bin/pgrep -f "worker_daemon.py" >/dev/null 2>&1; then
  echo "[smoke] worker process ok"
else
  echo "[smoke] worker process missing"
  exit 1
fi

echo "[done] runtime refresh completed successfully"
