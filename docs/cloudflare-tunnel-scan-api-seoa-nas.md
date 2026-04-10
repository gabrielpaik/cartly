# Cartly app public API via Cloudflare Tunnel (`scan-api.seoa-nas.com`)

## Goal

Expose only the app runtime API publicly for TestFlight / production app access, while keeping `/admin/*` separate behind the admin domain.

Recommended public URL:
- `https://scan-api.seoa-nas.com`

## Local topology

- Public app hostname: `scan-api.seoa-nas.com` → Cloudflare Tunnel → `app-public-proxy` on `127.0.0.1:3100`
- `app-public-proxy` forwards only app-safe routes to backend `127.0.0.1:8011`
- backend stays local/private on `127.0.0.1:8011`
- admin UI stays on its own domain (`wimc-admin.seoa-nas.com`) on separate `admin-web` service `127.0.0.1:3000`

## Public routes exposed for the app

- `/v1/auth/*`
- `/v1/scan/*`
- `/v1/carts/*`
- `/v1/events/*`
- `/v1/ads/*`
- `/v1/app-config`
- `/assets/branding/*`
- `/assets/ads/*`
- `/health`

Not exposed through this path:
- `/admin/*`

## Why this shape

- Flutter app can keep using the same backend path contract.
- Cloudflare exposes only the app-facing contract, not admin routes.
- backend keeps NAS access and login-session behavior on localhost.

## Required local runtime env

`$HOME/Library/Application Support/Cartly/admin.env`

```bash
export CARTLY_API_BASE='http://127.0.0.1:8011'
export APP_PUBLIC_PROXY_PORT='3100'
export APP_PUBLIC_PROXY_HOST='127.0.0.1'
export APP_PUBLIC_PROXY_BACKEND_BASE='http://127.0.0.1:8011'
```

`app-public-proxy` uses `APP_PUBLIC_PROXY_BACKEND_BASE` (defaulting to `CARTLY_API_BASE`) to reach the private backend.

## Cloudflare Tunnel setup

Add a new public hostname to the existing tunnel:

- Subdomain: `scan-api`
- Domain: `seoa-nas.com`
- Type: `HTTP`
- URL: `http://127.0.0.1:3100`

This intentionally points to a dedicated app-only proxy service, not the admin web process.

## TestFlight build

Use:

```bash
/Users/sdpaik/dev/wimc/scripts/build-ios-testflight-public.sh
```

Default target:

- `PUBLIC_BASE_URL=https://scan-api.seoa-nas.com`
- `APP_CONFIG_BASE_URL=https://scan-api.seoa-nas.com`

Override if needed:

```bash
PUBLIC_BASE_URL='https://scan-api.seoa-nas.com' \
APP_CONFIG_BASE_URL='https://scan-api.seoa-nas.com' \
/Users/sdpaik/dev/wimc/scripts/build-ios-testflight-public.sh
```

The script injects:

- `CARTLY_REMOTE_BASE_URL`
- `CARTLY_APP_CONFIG_BASE_URL`

## Expected result

- TestFlight app no longer falls back to `127.0.0.1`
- iPhone can reach auth / scan / cart APIs through Cloudflare
- backend and worker remain local and continue writing to NAS

## Smoke test checklist

1. `scan-api.seoa-nas.com/health` returns JSON
2. `scan-api.seoa-nas.com/v1/app-config` returns JSON
3. guest auth works through `POST /v1/auth/guest`
4. scan job create works through `POST /v1/scan/jobs`
5. worker drains the queued job
6. app receives scan result on real device
