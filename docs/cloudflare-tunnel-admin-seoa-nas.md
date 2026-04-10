# Cartly admin via Cloudflare Tunnel (`admin.seoa-nas.com`)

## Goal

Expose Cartly admin publicly through Cloudflare without opening local router ports.

Recommended public URL:
- `https://admin.seoa-nas.com`

Do **not** expose the root domain for admin.
Use a subdomain and keep backend private.

## Security posture

- Public: `admin.seoa-nas.com` → Cloudflare Tunnel → `admin-web` on `127.0.0.1:3000`
- Private only: backend API on `127.0.0.1:8011`
- App admin APIs still require `ADMIN_TOKEN`
- Recommended next layer: Cloudflare Access email allowlist on top of `ADMIN_TOKEN`

## Current local state

Verified on this Mac mini:
- `cloudflared` installed via Homebrew
- admin-web has login/token protection
- backend `/admin/*` requires `ADMIN_TOKEN`
- admin-web proxy route forwards authenticated admin requests to backend

## Runtime env

### Backend

```bash
cd /Users/sdpaik/dev/wimc
export ADMIN_TOKEN='replace-with-long-random-secret'
export API_BASE_URL='https://admin.seoa-nas.com'
uvicorn backend.app.main:app --host 127.0.0.1 --port 8011
```

Notes:
- backend stays on localhost only
- `API_BASE_URL` is used for branding asset URLs returned by backend

### Admin web

```bash
cd /Users/sdpaik/dev/wimc/admin-web
export CARTLY_API_BASE='http://127.0.0.1:8011'
npm run build
npm run start
```

Notes:
- admin-web now binds to `127.0.0.1:3000`
- browser traffic comes in through Cloudflare Tunnel only

## Cloudflare dashboard steps

Assumes `seoa-nas.com` is already active in your Cloudflare account.

1. Open Cloudflare Zero Trust dashboard.
2. Go to **Networks → Tunnels**.
3. Create a new tunnel.
4. Connector type: **cloudflared**.
5. Tunnel name suggestion: `wimc-admin-macmini`.
6. In **Public hostnames**, add:
   - Subdomain: `admin`
   - Domain: `seoa-nas.com`
   - Type: `HTTP`
   - URL: `http://127.0.0.1:3000`
7. Save the tunnel.
8. Cloudflare will show an install/run command for this machine.
   - Use the command Cloudflare generates for macOS.
   - For remotely-managed tunnels this is typically a `cloudflared service install ...` or token-based run command.

## Local connector start

Use the exact command shown by Cloudflare dashboard.

Typical flow:
- dashboard creates tunnel
- dashboard gives one command for this Mac
- run that command locally
- connector becomes Healthy
- `https://admin.seoa-nas.com` starts routing to local `127.0.0.1:3000`

## Recommended hardening after first boot

### 1) Add Cloudflare Access

Protect `admin.seoa-nas.com` with a policy such as:
- allow only your email address
- or allow only a small email/domain list

This gives you:
- Cloudflare identity check first
- Cartly `ADMIN_TOKEN` second

### 2) Keep backend off the network

Do not expose port `8011` publicly.
Do not create a separate public hostname for backend.

### 3) Rotate token when needed

If operators change:
- rotate `ADMIN_TOKEN`
- old sessions will be forced back to login automatically

## Smoke test

1. Start backend on `127.0.0.1:8011`
2. Start admin-web on `127.0.0.1:3000`
3. Run Cloudflare tunnel connector command
4. Open `https://admin.seoa-nas.com`
5. Confirm:
   - login page appears
   - correct `ADMIN_TOKEN` enters successfully
   - `/overview` loads
   - Content save works
   - branding logo upload works

## If something breaks

Check in this order:
1. `cloudflared` connector status in Cloudflare dashboard
2. local admin-web process on `127.0.0.1:3000`
3. local backend process on `127.0.0.1:8011`
4. backend has `ADMIN_TOKEN` set
5. `CARTLY_API_BASE` points to `http://127.0.0.1:8011`
6. app login succeeds but pages loop back to login → token mismatch or backend admin auth failure

## Nice next step

After first successful public boot:
- add launchd/system service for backend/admin-web
- keep cloudflared as service
- add Cloudflare Access policy
- then move cart/auth state from local device storage into backend source-of-truth
