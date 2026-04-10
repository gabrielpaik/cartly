# Cartly / WIMC Baseline Audit - 2026-04-10

## Purpose

Freeze the current repo situation before starting new development work.

This document is the checkpoint for:
- what is currently in the working tree,
- what looks like real product progress,
- what should be cleaned/classified before new feature work,
- what should happen next.

## Current repo state

Observed from `git status --short` / `git diff --stat` on 2026-04-10.

### Headline
- The repo is not in a clean development baseline.
- It contains one large accumulated batch of product work across app, backend, admin, docs, and platform scaffolding.
- Starting new features before checkpointing this state will blur real feature work with legacy uncommitted changes.

### Diff size
- `69 files changed, 6965 insertions(+), 1802 deletions(-)` in tracked diff
- large additional untracked set, including new app/backend/admin/runtime files

### Area breakdown
Current working tree is concentrated in these areas:
- Flutter app (`lib/**`) including auth, cart, ads, runtime config, preview, splash, detail pages
- Backend (`backend/**`) including admin routes, auth password flow, carts, ads runtime, app copy/branding, worker pipeline
- Admin web (`admin-web/**`) including auth/session proxying, admin chrome, content/ads/users/overview/config pages, preview integration
- iOS / platform scaffolding (`ios/**`, `android/**`, `macos/**`, etc.)
- scripts / docs / assets

## What looks like real product progress, keep and checkpoint

These changes look intentional and should be treated as real baseline work, not noise.

### 1. Product naming shift toward Cartly
- user-facing brand is moving from WIMC/ScanCart toward Cartly
- visible admin/app/auth copy already includes Cartly in multiple places
- `docs/CARTLY_RENAMING_PLAN.md` exists and matches the current transition strategy

### 2. Backend matured from MVP API to product backend
- email password auth flow exists
- guest -> member merge flow exists
- carts service exists with retention handling
- admin auth/session flow exists
- admin dashboard snapshot scheduling exists
- ads runtime and tracking endpoints exist
- app-config is acting as runtime source of truth

### 3. Admin web matured into actual control plane
- login/session middleware exists
- backend proxy routes exist
- overview, users, user detail, scan ops, carts, ads, content, config pages exist
- admin copy provider and runtime-managed labels exist
- preview pipeline exists and recent preview recovery work is reflected in the tree

### 4. Flutter app matured into runtime-driven app
- app config fetch/store exists
- remote auth/cart/scan repositories exist
- cart detail flow exists
- login/signup/reset flow exists
- AdMob integration exists
- banner/interstitial/rewarded support exists
- preview-safe app entry exists

### 5. Scan pipeline is no longer a toy flow
- scan job creation, polling, result read, failure log, feedback log exist
- dedicated worker path exists
- OpenClaw runner integration exists
- quarantine/retry admin paths exist

## Main risks discovered

### 1. No clean baseline
This is the most urgent risk.

Without a checkpoint commit, future work will mix:
- unfinished old work,
- deliberate new work,
- generated platform scaffolding,
- incidental environment noise.

### 2. Oversized Flutter composition
The app currently appears functionally strong but structurally dense.

Priority decomposition targets:
- `lib/main.dart`
- `lib/pages/login_page.dart`
- `lib/pages/cart_detail_page.dart`
- `lib/widgets/item_add_section.dart`

### 3. Backend admin surface is too concentrated
Highest-density files:
- `backend/app/routers/admin.py`
- `backend/app/services/ad_slot_service.py`
- `backend/app/services/admin_service.py`

These should be split after baseline checkpointing.

### 4. Retention extension still has a backend trust gap
- `backend/app/routers/carts.py` still includes TODO for verified rewarded-ad proof before granting retention extension.
- Current state is acceptable for internal MVP iteration, but not for hardened product logic.

### 5. Test coverage is still weak
- Flutter test surface is minimal
- backend test surface appears minimal relative to the amount of live business logic now present

### 6. Ops still depends on login-session execution discipline
- backend/storage health still depends on the chosen login-session run mode
- this is an operational constraint that should be documented and later reduced

## Classification guidance before any new feature work

### Batch A, baseline commit candidates
These appear to be real product work and should likely be reviewed, staged, and checkpointed intentionally:
- `lib/**`
- `backend/app/**`
- `admin-web/**`
- `scripts/**`
- `docs/CARTLY_RENAMING_PLAN.md`
- related runtime/docs needed by the current product direction

### Batch B, platform scaffolding to verify separately
These should not be mixed blindly with product logic review:
- `ios/**`
- `android/**`
- `macos/**`
- `linux/**`
- `windows/**`
- `web/**`

They may be legitimate, but they need explicit “keep as baseline” confirmation.

### Batch C, likely non-product or environment-specific review bucket
Needs deliberate keep/drop decision before checkpoint:
- `.claude/**`
- `tmp/**`
- asset replacements that may just be intermediate work
- generated/runtime-support files that do not belong in long-term source control unless intentional

## Recommended immediate execution order

### Step 1. Freeze baseline intentionally
Do not add new features yet.

First:
1. classify changed files into product / platform / local-noise
2. decide what belongs in source control
3. create a checkpoint commit once the set is coherent

### Step 2. Finish first-pass Cartly rename
After baseline is stable:
- complete user-facing Cartly naming across app/admin/auth/default runtime copy
- keep internal WIMC infra names for now
- do not rename repo path, env keys, bundle id, or storage roots in first pass

### Step 3. Decompose Flutter structure
Priority after rename:
- split app shell / tabs / orchestration away from `lib/main.dart`
- isolate auth flow logic
- isolate saved cart and cart detail logic
- isolate ad handling from screen logic

### Step 4. Harden backend/admin architecture
After app structure cleanup:
- split admin router/service surfaces
- split ad slot/history logic
- add retention proof validation
- add tests around auth/cart/admin flows

## Recommended next concrete working session

The next session should do exactly this:

1. produce a keep/drop/stage table for current working tree
2. separate product baseline files from platform scaffolding and local noise
3. make the first checkpoint commit
4. begin first-pass Cartly rename only after that checkpoint exists

## Short operator judgment

This codebase is already beyond prototype stage.
The correct move now is not “add more stuff first”.
The correct move is:
- baseline,
- checkpoint,
- rename completion,
- structure cleanup,
- then new feature work.
