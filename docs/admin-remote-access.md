# Cartly admin remote access MVP

## Goal

Expose `admin-web` outside the local machine without leaving `/admin/*` open.

Current MVP approach:
- `admin-web` can bind to `0.0.0.0:3000`
- backend stays on its normal port (ex: `8011`)
- backend `/admin/*` requires `ADMIN_TOKEN`
- admin-web stores the token in an httpOnly cookie after successful login
- all browser admin requests go through Next route handlers, which proxy to backend with `Authorization: Bearer <token>`

## Required env

### Backend

```bash
export ADMIN_TOKEN='set-a-long-random-secret'
export API_BASE_URL='https://your-api-base.example.com'
# optional existing values
export DATABASE_URL='postgresql+psycopg://localhost:5432/cartly'
export STORAGE_ROOT='/Volumes/AI/Cartly'
```

Run backend on an externally reachable bind address only if you actually need that.

Example:

```bash
uvicorn backend.app.main:app --host 0.0.0.0 --port 8011 --reload
```

### Admin web

```bash
cd admin-web
export CARTLY_API_BASE='http://127.0.0.1:8011'
npm run build
npm run start
```

If admin-web and backend run on different hosts, point `CARTLY_API_BASE` at the backend base URL.

## Access flow

1. Open `/login`
2. Enter `ADMIN_TOKEN`
3. admin-web validates it against `GET /admin/session`
4. If valid, admin-web exchanges the root admin token for a revocable admin session and stores `cartly_admin_session` as an httpOnly cookie
5. All admin page fetches proxy through `/api/cartly-admin/*`

## What is protected

Protected backend endpoints:
- `GET /admin/session`
- `GET /admin/dashboard/summary`
- `GET /admin/users`
- `GET /admin/scan-jobs`
- `GET /admin/ads/slots`
- `GET /admin/branding`
- `PUT /admin/branding`
- `POST /admin/branding/logo`
- `GET /admin/config`

`/v1/app-config` stays separate because the app runtime needs it.

## Recommended exposure order

### Safer first: Tailscale / private network

Recommended when only internal operators need access.

- expose `admin-web:3000` on tailnet or private VPN
- keep backend reachable only from the admin-web host if possible
- still require `ADMIN_TOKEN`

### Public internet

If you want normal public domain access:

- put HTTPS reverse proxy in front (Caddy/Nginx/Cloudflare Tunnel, etc.)
- expose only `admin-web`
- keep backend direct port unlisted / firewalled if possible
- still require `ADMIN_TOKEN`
- rotate `ADMIN_TOKEN` when operators change

## Operational notes

- If `ADMIN_TOKEN` changes, new admin logins need the new root token; issued admin sessions can be revoked via `/admin/logout` and are rotated through backend-issued session tokens.
- If `ADMIN_TOKEN` is not set, backend `/admin/*` returns `503 ADMIN_TOKEN_NOT_CONFIGURED`.
- `admin-web` no longer needs direct browser access to backend; it uses server-side proxy routes.
- For this deployment, backend storage stays on `/Volumes/AI/Cartly` and the backend itself should run in a Terminal login-session context (not a direct launchd background process) so NAS writes remain permitted.

## Next hardening steps

1. replace shared token with real admin accounts / RBAC
2. add audit log for admin content/config changes
3. add rate limiting on `/admin/session`
4. add reverse proxy allowlist or SSO if public
5. move admin metrics fully off fallback/mock mode
