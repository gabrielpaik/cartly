# Cartly Current State

Last updated: 2026-05-19
Status: canonical current-state document

## What Cartly is now

Cartly is a grocery-shopping assistant centered on one continuous user flow:
- scan products or receipts
- manage the current cart
- save shopping results as reusable history
- revisit same-intent alternatives in Explore

The product direction is not generic ecommerce and not broad social shopping.
It is a personal decision-support tool for real grocery planning and review.

## Current product/runtime status

### Customer app
- Latest uploaded iOS build on App Store Connect: `1.0.5 (10)`
- Latest uploaded Android internal-testing build: `1.0.5 (39)`
- Shared household current-cart collaboration v2 is implemented and shipped in build 25.
- Guest mode exists.
- Member-only features include profile management, family sharing, and account deletion.
- Receipt flow is customer-facing source-of-truth apply/undo, not cart-vs-receipt comparison review.
- Location usage remains foreground-only and purpose-limited to nearby market discount information.
- Latest polish pass added: home/explore shared header rhythm stabilization, shopping-mode immersive red header band, bottom/body anti-shake cleanup, and the final red-band height extension accepted in review.

### Admin / operator surfaces
The admin relayout is no longer a proposal-only state.
Its durable direction is an operator-console grammar:
- dense headers
- table/list first
- compact filters
- selected-item sheet/workspace instead of long page forms
- runtime verification over source assumptions

Operations is treated as the completed baseline.
Growth received the active relayout passes.

Implemented/accepted state includes:
- Users: customer DB + segmentation console
- Push: campaign console with direct-upload audience flow and server-side device-state re-resolution
- Ads: campaign-row source-of-truth, targeting, region handling, and live runtime verification flow

### Public/business web
The public site has been reworked toward proposal-grade presentation rather than a temporary support page.
Current direction:
- two-card hero opening
- denser left-side proposal narrative
- clickable feature preview section using real app screenshots
- one-line footer with wordmark, app version, and support/proposal links
- shorter hero copy direction: `장보기 기록과 대체안`

## Branding state

### Public/admin/runtime config
Current branding runtime target/state:
- `logoType: image`
- `logoText: Cartly`
- `logoImageUrl: https://scan-api.seoa-nas.com/assets/branding/cartly_logo_vectorized.svg`
- `splashImageUrl: https://scan-api.seoa-nas.com/assets/branding/cartly_splash_default.png`
- until a new admin-managed splash is uploaded, the native launch and app splash baseline is the bundled cart-pushing photo asset matching `cartly_splash_default.png`

### App-side caution
A real-device issue surfaced where the top home header could still fall back to plain text if the remote SVG logo did not render as expected on-device.
To harden this, source now includes:
- bundled local SVG fallback in `lib/widgets/brand_mark.dart`
- increased header title height in `lib/pages/home_tab_view.dart`

This fix path is now on the current review build line through `1.0.5 (10)`.

## Store/release status

### iOS / App Store Connect
- Current review candidate build: `1.0.5 (10)`
- Build delivery UUID: `90a8d53b-1417-40d8-b263-d227a0d43293`
- Metadata, screenshots, privacy URL, support URL, and review contact have already been prepared.
- Build `1.0.5 (10)` is uploaded and ready to be attached to the current App Store version for review submission.
- Remaining caution: if the admin splash changes again later, the iPhone native first screen still requires a fresh bundled-asset rebuild and new upload.

### Android / Google Play
- Signed release AAB builds locally.
- Repo-side Play internal upload automation now exists at `scripts/upload-android-play-internal.rb`.
- Latest uploaded Android internal-testing build is `1.0.5 (39)`.
- The dedicated Play-linked service-account JSON is now restored at `~/Library/Application Support/Cartly/play/cartly-play-api.json`, copied from the NAS-mounted file `/Volumes/downloads/cartly-e36ee-dcb07ec17251.json`.
- Re-test on 2026-05-19 confirmed the available Firebase Admin SDK JSON (`firebase-adminsdk-fbsvc@cartly-e36ee.iam.gserviceaccount.com`) still fails Android Publisher at edit creation with `403 PERMISSION_DENIED`, so it cannot substitute for the dedicated Play-linked service-account key.
- Remaining work is listing, data safety, content rating, app access, and final review/submission ops.

## Public URLs
- App/public root: `https://scan-api.seoa-nas.com/`
- Privacy: `https://scan-api.seoa-nas.com/privacy`
- Support: `https://scan-api.seoa-nas.com/support`
- Public admin: `https://cartly-admin.seoa-nas.com`

## Canonical working rules
- Treat live-served runtime behavior as the source of truth for admin/public verification.
- After admin-web/public-site changes, refresh the served runtime before reporting success.
- For screenshot-driven public-site presentation, prefer real app captures over mock or invented compositions.
- Release cadence rule: run iOS TestFlight and Android internal testing together by default, then align final platform approval/submission together unless the user explicitly wants a split rollout.
- Use this document as the primary current-state entry point instead of chaining multiple handoff/checkpoint notes.

## Open next actions
1. Submit iOS build `1.0.5 (10)` and the matching Android `1.0.5 (39)` release line into store review together.
2. If Google Play install/listing surfaces still look generic, clean up the Play listing high-res icon and store metadata separately from the binary.
3. If the admin splash changes again, re-sync bundled splash assets and ship a new paired build before expecting native iPhone launch parity.
