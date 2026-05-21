# Cartly Current State

Last updated: 2026-05-21
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
- iOS public release is now live on the App Store as `카트리`: `https://apps.apple.com/kr/app/카트리/id6763728346`
- Latest shipped iOS public release line is still `1.0.5 (10)`.
- Latest submitted iOS App Store review candidate is now `1.0.7 (14)`.
- Latest iOS delivery UUID is `3b276e1e-12c4-4404-8fd8-824d7a1b89db`.
- Latest uploaded Android internal-testing build: `1.0.7 (45)`.
- Latest locally verified Android release artifact is `1.0.7 (45)`.
- Shared household current-cart collaboration v2 is implemented and shipped in build 25.
- Guest mode exists.
- Fresh-install guest bootstrap is now hardened: if the app has no persisted session, it auto-creates a guest session and emits an authenticated `app_open` event so first visits surface in both the customer DB and activity metrics.
- Member-only features include profile management, family sharing, and account deletion.
- Receipt flow is customer-facing source-of-truth apply/undo, not cart-vs-receipt comparison review.
- Location usage remains foreground-only and purpose-limited to nearby market discount information.
- The latest iOS review-warning mitigation pass removed the unused `permission_handler` dependency and applied `BYPASS_PERMISSION_LOCATION_ALWAYS=1` to `geolocator_apple`, so the shipped build path no longer carries the previous always-location review risk.
- Latest polish pass added: home/explore shared header rhythm stabilization, shopping-mode immersive red header band, bottom/body anti-shake cleanup, and the final red-band height extension accepted in review.
- iOS AdMob app approval mail has arrived, `app-ads.txt` is publicly served, and real-device ad display was verified on iPhone across the currently exposed paths, so Cartly is now past configuration-only status and into real monetization observation.
- Explore alternative-search behavior is now intentionally in a utility-first state: filtered Naver Shopping results are shown directly in-app while LinkPrice deeplink monetization is still unresolved.
- The latest Explore cleanup pass also removed the redundant `decisionInbox` layer and separated visible `비교 후보` from non-duplicative `다시 볼 상품` / `반복 구매` lists.
- The newest follow-up Flutter Explore patch restores admin-driven section behavior in the app, re-enables `decisionInbox` as fallback-hidden real UI instead of hard removal, allows admin-enabled recommendation picks during `activeShopping`, and cleans awkward `대안상품 보기` meta-like detail copy.
- The current mobile release wave bundles the ranked single-pool recommendation surface, admin-curated plus search alternative blending, the Flutter-side full-banner rendering alignment for current direct-banner slots, and the new admin-truth Explore restoration pass.

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
- Push: campaign console with direct-upload audience flow, server-side device-state re-resolution, and a live recurring weekly schedule surface persisted server-side
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

This fix path is now carried forward through the current submitted review build `1.0.7 (13)`.

## Store/release status

### iOS / App Store Connect
- Current shipped public iOS app: `카트리`
- Public App Store URL: `https://apps.apple.com/kr/app/카트리/id6763728346`
- Latest shipped public iOS build line: `1.0.5 (10)`
- Latest submitted App Store review build is now `1.0.7 (14)` with delivery UUID `3b276e1e-12c4-4404-8fd8-824d7a1b89db`.
- App Store version `1.0.7` is attached to build `14` and is back in `WAITING_FOR_REVIEW` after removing the earlier build `13` submission and re-submitting the version on build `14`.
- The newly submitted `1.0.7 (14)` build carries forward the current guest/bootstrap and cart-default fixes, the iOS location-permission mitigation, the utility-first Explore cleanup, ranked single-pool recommendation flow, admin-curated plus search alternative blending, Flutter-side full-banner promo rendering updates, and the admin-truth Explore restoration/detail-cleanup follow-up.
- Metadata, screenshots, privacy URL, support URL, review contact, and App Review notes were updated successfully and were sufficient for submission.
- Immediate post-release nuance: direct App Store URL is live, but search/discovery indexing can lag for a while after release, so early promotion should prefer the direct link.
- Remaining caution: if the admin splash changes again later, the iPhone native first screen still requires a fresh bundled-asset rebuild and new upload.

### Android / Google Play
- Signed release AAB builds locally.
- Repo-side Play internal upload automation now exists at `scripts/upload-android-play-internal.rb`.
- Latest uploaded Android internal-testing build is `1.0.7 (45)`.
- Latest locally verified Android release AAB is `1.0.7`, versionCode `45`, at `build/app/outputs/bundle/release/app-release.aab`.
- The dedicated Play-linked service-account JSON is now restored at `~/Library/Application Support/Cartly/play/cartly-play-api.json`, copied from the NAS-mounted file `/Volumes/downloads/cartly-e36ee-dcb07ec17251.json`.
- Re-test on 2026-05-19 confirmed the available Firebase Admin SDK JSON (`firebase-adminsdk-fbsvc@cartly-e36ee.iam.gserviceaccount.com`) still fails Android Publisher at edit creation with `403 PERMISSION_DENIED`, so it cannot substitute for the dedicated Play-linked service-account key.
- Store listing/app-content setup was pushed much farther on 2026-05-19 night, but final production launch is still blocked by Google Play's personal-account closed-testing gate: before production access, Cartly must run a closed test with at least 12 opted-in testers for 14 days.
- The Android test tracks are now aligned to `1.0.7 (45)` on both internal and alpha, and this tester build now includes the ranked Explore recommendation release wave, the Flutter-side full-banner/direct-banner rendering changes, and the app-side admin-truth Explore restoration/detail cleanup. Immediate Android release work remains tester recruitment, active closed-test operation, and waiting out the Play-required test window.

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
1. Monitor App Review for the now-resubmitted iOS build `1.0.7 (14)` and be ready to answer any reviewer follow-up quickly.
2. Validate that fresh installs on `1.0.7 (14)` now create guest users immediately, produce authenticated `app_open` activity, and reflect the restored admin-truth Explore behavior on-device.
3. Continue from the now-uploaded Android internal + alpha build `1.0.7 (45)` toward the Play closed-test requirement, including 12 opted-in testers and the 14-day gate.
4. If Google Play install/listing surfaces still look generic during the closed-test period, keep cleaning up the Play listing high-res icon and store metadata separately from the binary.
5. Keep the admin customer table clean during early rollout; as of 2026-05-20 morning, old test accounts were cleaned out and only `백승대` and `이지민` remained as active pre-launch accounts.
6. Post-launch operator focus has now shifted to the operations/growth workstream captured in `docs/operations-growth-workstream-2026-05.md`: recurring Friday push scheduling, Coupang partner-product automation, AdMob verification, and direct-banner design guidance.
7. The first scheduled-push MVP is now implemented, deployed, and enabled live as a weekly Friday 18:30 KST push baseline. The next validation should be a real dry-run observation when that schedule actually fires or via a controlled manual send.
8. AdMob verification is no longer only theoretical. Real production app IDs are present on Android/iOS, `app-ads.txt` is publicly exposed, and iPhone real-device validation confirmed actual ad display on the shipped banner/interstitial/rewarded paths. The next operator check is report accumulation and revenue/impression trend observation rather than config guessing.
9. The first practical direct-banner design guide is now drafted at `docs/02_product/direct-banner-design-guide.md`, with Cartly-aligned example mockups for the current slot shapes under `docs/02_product/direct-banner-examples/`.
10. Next monetization execution step can move toward operator-uploaded direct banner inventory now that baseline AdMob runtime behavior is verified.
11. If the admin splash changes again, re-sync bundled splash assets and ship a new paired build before expecting native iPhone launch parity.
