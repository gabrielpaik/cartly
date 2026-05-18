# Cartly Current State

Last updated: 2026-05-18
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
- Latest uploaded iOS build on App Store Connect: `1.0.4 (27)`
- Latest uploaded Android internal-testing build: `1.0.4 (27)`
- Shared household current-cart collaboration v2 is implemented and shipped in build 25.
- Guest mode exists.
- Member-only features include profile management, family sharing, and account deletion.
- Receipt flow is customer-facing source-of-truth apply/undo, not cart-vs-receipt comparison review.
- Location usage remains foreground-only and purpose-limited to nearby market discount information.
- Latest polish pass added: home logo Cartly-red rendering hardening, home/explore header height alignment, and logout confirmation popup.

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

### App-side caution
A real-device issue surfaced where the top home header could still fall back to plain text if the remote SVG logo did not render as expected on-device.
To harden this, source now includes:
- bundled local SVG fallback in `lib/widgets/brand_mark.dart`
- increased header title height in `lib/pages/home_tab_view.dart`

This fix exists in source but is **not yet on the user’s phone** until the next iOS/TestFlight build is shipped.

## Store/release status

### iOS / App Store Connect
- Current review candidate build: `1.0.4 (27)`
- Build delivery UUID: `9ee9152a-588d-430c-a627-aa164d37b137`
- Metadata, screenshots, privacy URL, support URL, and review contact have already been prepared.
- Build 27 is uploaded; TestFlight visibility/final eye review should be checked alongside Android internal testing.
- Remaining manual console work still includes final App Store Connect questionnaire/submission steps.

### Android / Google Play
- Signed release AAB builds locally.
- Play service-account automation is now connected and usable.
- Internal testing track upload for build `27` is complete.
- Remaining work is no longer auth/setup; it is listing, data safety, content rating, app access, and final review/submission ops.

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
1. Eye-review build `1.0.4 (27)` on both iOS TestFlight and Android internal testing together.
2. Finish the latest-only MD cleanup pass so canonical docs stay foreground and superseded notes stay archived.
3. Final-verify the public site after the latest screenshot and footer/logo adjustments.
4. Resume synchronized iOS/Android store-console submission work once build 27 is accepted.
