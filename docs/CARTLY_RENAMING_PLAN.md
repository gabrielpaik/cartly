# Cartly Renaming Plan

## Decision

- External brand name moves to **Cartly**.
- Existing internal/runtime codename **WIMC** stays temporarily where changing it would risk runtime breakage.
- Current repo/app structure is kept for now. Do **not** do a big-bang move into a new folder during the first renaming pass.
- If cleanup is still needed after branding stabilizes, do a second pass to create a lighter clean project shell.

## Why not move into a new folder now

Brand references are spread across app, admin, backend, scripts, docs, env keys, bundle ids, storage paths, and launch/runtime paths.
A simultaneous rename + folder move would increase break risk across:

- backend startup scripts
- admin-web runtime/start paths
- launch agents and logs
- NAS storage paths
- public proxy / Cloudflare docs and runbooks
- bundle/package ids and testflight packaging

Recommended order:

1. Rename external/user-facing brand to Cartly
2. Stabilize runtime and publishing copy
3. Reassess whether a clean-folder migration is still worth it

## Scope buckets

### 1) User-facing, change first

These should move to **Cartly** in the first pass.

#### App / iOS
- `ios/Runner/Info.plist`
  - app display name currently shows `ScanCart`
- `lib/models/app_branding.dart`
- `lib/services/remote_auth_repository.dart`
  - fallback user display name `ScanCart User`
- user-visible app runtime copy from backend/app-config

#### Backend user-visible copy
- `backend/app/services/auth_password_service.py`
  - signup/reset email subject/body still says `ScanCart`
- backend branding/app-copy defaults where app/admin preview text surfaces to the user

#### Admin user-facing text
- `admin-web/components/LoginScreen.tsx`
  - `WIMC Admin 로그인`
- `admin-web/components/AdminChrome.tsx`
  - `WIMC Admin`
- `admin-web/app/layout.tsx`
  - title/description currently `WIMC Admin`
- admin copy defaults and preview labels that surface app/admin brand name

### 2) Operational/internal text, change selectively

These can be renamed if low-risk, but do not block first-pass Cartly rollout.

- docs titles and narrative references:
  - `docs/operations-runbook.md`
  - `docs/admin-remote-access.md`
  - `docs/admin-architecture.md`
  - `docs/admin-frontend-spec.md`
  - `docs/api-spec-draft.md`
  - `docs/db-schema-draft.md`
  - `docs/commercial-architecture.md`
  - `docs/cloudflare-tunnel-*.md`
- ad export labels in backend:
  - `backend/app/services/ad_slot_service.py`
    - `WIMC Ad Campaign Export`
    - filenames like `wimc-ad-campaigns-*`
- prompts/help text in scripts like OCR runner descriptions

Recommendation: rename visible docs/export labels to Cartly where useful, but keep file paths/stable infra names unless there is a real benefit.

### 3) Technical/internal identifiers, keep for now

These should stay until a dedicated technical migration step.

- repo path: `/Users/sdpaik/dev/wimc`
- bundle id: `com.seungdae.wimc`
- env keys:
  - `WIMC_API_BASE`
  - `WIMC_REMOTE_BASE_URL`
  - `WIMC_APP_CONFIG_BASE_URL`
- storage path:
  - `/Volumes/AI/WIMC`
  - `~/Library/Application Support/WIMC`
  - `~/Library/Logs/WIMC`
- script names:
  - `WIMC Backend.command`
  - `WIMC Worker.command`
- code identifiers that are stable but not user-facing:
  - `WimcRuntimeConfig`
  - install id keys like `wimc_install_id_v1`
  - multipart boundaries / probe files / scheduler names
- internal service hostnames/domains unless explicitly re-scoped later:
  - `scancart-api.seoa-nas.com`
  - `wimc-admin.seoa-nas.com`

## First-pass execution plan

### Phase A, brand policy lock
- External product/app/service name: **Cartly**
- Admin visible name: recommend **Cartly Admin**
- Internal codename: keep **WIMC** for now
- Bundle id: keep `com.seungdae.wimc` for now

### Phase B, rename user-facing brand
1. App visible name/default copy
2. Admin visible branding text
3. Auth email subjects/bodies
4. Backend/app-config default branding/copy values
5. Preview/default content labels that still say WIMC or ScanCart

### Phase C, verify runtime reflection
After edits:
- admin save -> backend -> `/v1/app-config` reflection
- app visible brand text = Cartly
- auth mail subject/body = Cartly
- admin login/nav/layout brand = Cartly Admin

### Phase D, optional second pass
Only after Phase B/C are stable:
- decide whether to create a new clean folder/app shell
- if yes, migrate by copy/verify, not by in-place destructive move

## Immediate target files for next work session

### Highest priority
- `ios/Runner/Info.plist`
- `backend/app/services/auth_password_service.py`
- `backend/app/services/app_copy_service.py`
- `backend/app/services/branding_service.py`
- `lib/models/app_branding.dart`
- `lib/services/remote_auth_repository.dart`
- `admin-web/components/LoginScreen.tsx`
- `admin-web/components/AdminChrome.tsx`
- `admin-web/app/layout.tsx`
- `admin-web/app/content/page.tsx`

### Review right after
- `backend/app/services/ad_slot_service.py`
- `lib/services/api_base.dart`
- `lib/services/app_config_store.dart`
- `lib/config/wimc_runtime_config.dart`
- docs with public-facing naming or screenshots/copy guidance

## Explicit do-not-touch in first pass
- repo directory names
- launch agent labels
- storage/log directory roots
- bundle id / package identifiers
- env var names
- tunnel/internal hostname scheme

## Success condition for first pass

A user or tester should see **Cartly** consistently across:
- app display name
- app visible branding/copy defaults
- auth emails
- admin visible brand labels

while runtime stays stable on the existing WIMC-based internal paths.
