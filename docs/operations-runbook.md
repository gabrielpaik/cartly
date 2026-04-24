# Cartly Operations Runbook

## Current production-ish operating model

### Backend
- Runs in a **Terminal login-session context** on the Mac mini
- Do **not** run the backend as a direct launchd background process
- Reason: direct launchd backend writes to `/Volumes/AI/Cartly` fail with `PermissionError`, while the same backend launched from the user login session writes successfully
- Actual login-session entrypoint now starts a lightweight **runtime supervisor** that keeps backend and worker alive inside that same Terminal/login-session context

### Scan worker
- Runs as a **Terminal login-session daemon** on the Mac mini
- Entrypoint: `/Users/sdpaik/dev/wimc/scripts/Cartly Worker.command`
- Runtime loop: `/Users/sdpaik/dev/wimc/backend/worker_daemon.py`
- Current purpose: continuously drain queued scan jobs from DB/NAS without requiring manual one-shot worker execution
- In normal operations, the runtime supervisor also restarts the worker automatically if it dies unexpectedly

### Admin web
- Still runs as the existing LaunchAgent (`com.wimc.admin-web.plist`)
- Public access remains through the existing admin domain / reverse proxy path
- After backend/admin source changes, do not rely on an already-running `next start` process staying fresh. Use the runtime refresh script below so the live process is rebuilt/restarted deterministically.

### Storage
- Storage root stays on NAS volume: `/Volumes/AI/Cartly`
- Backend startup performs storage preflight checks and `/health` exposes:
  - `storageWritable`
  - `storagePaths`
  - `storageErrors`

---

## Startup / login behavior

### Expected login flow
1. User logs into macOS
2. Login Item app opens Terminal and runs the backend entry script. Primary login item app is now `Cartly Backend Login.app`, while the legacy `WIMC Backend Login.app` can remain as a temporary compatibility backup:
   - `/Users/sdpaik/Applications/Cartly Backend Login.app`
   - `/Users/sdpaik/dev/wimc/scripts/Cartly Backend.command`
   - `/Users/sdpaik/dev/wimc/scripts/WIMC Backend.command` (legacy compatibility shim if the old app is still launched manually)
3. That command launches:
   - `/Users/sdpaik/dev/wimc/scripts/run-backend-login-session.sh`
4. Backend launcher starts:
   - `/Users/sdpaik/dev/wimc/scripts/run-runtime-supervisor-login-session.sh`
5. Supervisor keeps checking backend + worker and restarts either one when missing
5-b. Runtime refresh launches the supervisor in a detached session/process group so OpenClaw gateway restarts do not take backend + worker down with them
6. Launchers first try to restore the NAS mount via:
   - `/Users/sdpaik/dev/wimc/scripts/ensure-nas-mount.sh`
7. Backend child launcher starts uvicorn only if port `8011` is not already listening

### Expected result
- Backend listens on `127.0.0.1:8011`
- Runtime supervisor process stays alive in the login-session context
- Worker daemon is automatically re-started if it disappears
- `/health` returns `storageWritable: true`
- Scan job creation can write directly into `/Volumes/AI/Cartly`

---

## Refresh after backend/admin changes

### Canonical refresh command
```bash
<repo>/scripts/Cartly\ Runtime\ Refresh.command
```

What it does:
1. rebuilds the admin-web production bundle
2. optionally rebuilds app-preview when you pass `--with-preview`
3. stops anything currently listening on `127.0.0.1:3000` and `127.0.0.1:8011`
4. stops and restarts the runtime supervisor + admin-web from the repo scripts
5. runs a small smoke check for `/health`, `/v1/app-config`, and critical admin API paths

### Optional preview refresh
```bash
<repo>/scripts/Cartly\ Runtime\ Refresh.command --with-preview
```

Use this when Flutter preview code changed and `/content` should reflect a fresh `app-preview` build.

## Verification commands

### 1) Backend health
```bash
curl -sS http://127.0.0.1:8011/health
```

Healthy expected fields:
```json
{
  "ok": true,
  "storageWritable": true
}
```

### 2) Process check
```bash
pgrep -fal 'uvicorn backend.app.main:app --host 127.0.0.1 --port 8011'
```

### 2-b) Supervisor check
```bash
pgrep -fal 'runtime_supervisor.py'
```

### 3) Quick scan write proof
```bash
printf 'fake-image' >/tmp/cartly-check.jpg
TOKEN=$(curl -sS -X POST http://127.0.0.1:8011/v1/auth/guest \
  -H 'Content-Type: application/json' \
  --data '{"deviceId":"ops-check","platform":"ios","appVersion":"0.1.0"}' | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["session"]["token"])')

curl -sS -X POST http://127.0.0.1:8011/v1/scan/jobs \
  -H "Authorization: Bearer $TOKEN" \
  -F image=@/tmp/cartly-check.jpg
```

---

## Day-2 operations

### Restart backend manually
If backend is unhealthy or missing after login:
1. Open Terminal
2. Run:
```bash
<repo>/scripts/Cartly\ Backend.command
```

This now restores the login-session runtime supervisor, which in turn restores backend + worker.

### Stop backend manually
```bash
pkill -f 'uvicorn backend.app.main:app --host 127.0.0.1 --port 8011'
```

### Check admin web
```bash
curl -sS http://127.0.0.1:3000/login >/dev/null && echo ok
```

### Canonical stale-process recovery
If admin routes or exports behave like old code is still running, refresh the whole runtime instead of manually poking one process at a time:
```bash
<repo>/scripts/Cartly\ Runtime\ Refresh.command
```

---

## What not to do

### Do not re-enable direct backend LaunchAgent
Avoid restoring or reusing a direct backend plist under `~/Library/LaunchAgents` for uvicorn itself.

Why:
- launchd background backend can pass health checks
- but still fail actual NAS writes to `/Volumes/AI/Cartly`
- that breaks scan job creation in production paths

### Do not move OCR input/logs to local disk as a permanent workaround
The chosen operating model intentionally keeps OCR storage on the NAS volume for continuous operations.

---

## Admin UI checks

### Overview
Use `/overview` to confirm lifecycle KPIs, top members by saved carts, and high-level app operations metrics.

### Scan Ops
Use `/scan-ops` to confirm:
- feedback totals
- accepted vs corrected counts
- recent feedback rows
- recent failure rows

### Config
Use `/config` to confirm:
- backend run mode = `terminal-login-session`
- `storageWritable = true`
- current NAS storage paths

---

## Incident notes

### Symptom: `/v1/scan/jobs` returns 500 with PermissionError
Interpretation:
- backend process is likely not running in the login-session Terminal context
- or NAS mount/session permissions changed after login

Immediate actions:
1. Check `/health`
2. Confirm `storageWritable`
3. Confirm `/Volumes/AI` is mounted, or run `/Users/sdpaik/dev/wimc/scripts/ensure-nas-mount.sh`
4. Re-run `Cartly Backend.command` from Terminal
5. Retry a scan job

### Symptom: Login Item ran but backend is not listening
Immediate actions:
1. Open Terminal
2. Run `/Users/sdpaik/dev/wimc/scripts/Cartly Backend.command`
3. Re-check `curl -sS http://127.0.0.1:8011/health`

### Symptom: admin pages load but `/api/cartly-admin/*` behaves like old code
Common signals:
- `/api/cartly-admin/*` returns 404 while older `/api/wimc-admin/*` paths still answer
- an export or admin endpoint throws a stack trace that points at old line numbers after a refactor

Interpretation:
- admin-web and/or backend is still serving a stale already-running process rather than the latest source/build

Immediate action:
1. Run `/Users/sdpaik/dev/wimc/scripts/Cartly Runtime Refresh.command`
2. Re-check `/login`, `/api/cartly-admin/admin/dashboard/summary`, and `/health`

---

## Local file references
- Backend login-session runner:
  - `/Users/sdpaik/dev/wimc/scripts/run-backend-login-session.sh`
- Runtime supervisor:
  - `/Users/sdpaik/dev/wimc/scripts/run-runtime-supervisor-login-session.sh`
- Backend child launcher:
  - `/Users/sdpaik/dev/wimc/scripts/run-backend-once-login-session.sh`
- Terminal entrypoint:
  - `/Users/sdpaik/dev/wimc/scripts/Cartly Backend.command`
- Full runtime refresh entrypoint:
  - `/Users/sdpaik/dev/wimc/scripts/Cartly Runtime Refresh.command`
- NAS mount preflight helper:
  - `/Users/sdpaik/dev/wimc/scripts/ensure-nas-mount.sh`
- Login-session runtime log:
  - `/Users/sdpaik/Library/Logs/Cartly/backend-login-session.log`
- Runtime supervisor log:
  - `/Users/sdpaik/Library/Logs/Cartly/runtime-supervisor.log`
- Admin web runtime log:
  - `/Users/sdpaik/Library/Logs/Cartly/admin-web.log`
- Runtime refresh log:
  - `/Users/sdpaik/Library/Logs/Cartly/runtime-refresh.log`
- Admin web LaunchAgent:
  - `~/Library/LaunchAgents/com.wimc.admin-web.plist`
