# Cartly Operations / Growth Workstream (2026-05)

Last updated: 2026-05-29
Status: active next workstream
Purpose: capture the post-launch operator improvements that now matter more than release packaging

## Scope

This document is for the next operating-improvement phase after iOS public launch.
Do **not** use it for Android tester recruiting logistics.
That recruiting can stay conversational/operational without a dedicated md.

## Confirmed workstreams

### 1. Scheduled app push
Goal:
- send a recurring app push every Friday at 18:30 KST
- baseline message: `이번주말 카트리로 쇼핑 어때요?`

What "done" should mean:
- operator can create a scheduled push in admin instead of sending manually each week
- timezone handling is explicit and stable (`Asia/Seoul`)
- recurring schedule is persisted server-side, not left to a browser tab staying open
- operator can pause, resume, edit, or cancel the recurring push
- delivery result / target count / failure count can be checked afterward

Implementation status on 2026-05-20:
- first MVP is now coded as an `app_settings`-backed recurring schedule, not a new schedule table
- backend startup/runtime now includes a recurring push scheduler loop
- dispatch materializes normal `push_campaigns` history rows at send time, so delivery history stays in the existing campaign log
- admin push page now includes enable/pause/edit controls for the weekly schedule
- current MVP is intentionally one-attempt-per-slot. If runtime is blocked at the fire time, the operator should fix the blocker and re-send manually instead of expecting same-slot auto-retries

Questions left after MVP:
- whether recurring schedules should later become first-class DB rows instead of a single settings-backed schedule
- whether multiple recurring schedules are needed instead of one baseline weekly operator campaign
- whether segmentation should stay broad first or support audience filters from day one

### 2. Coupang Partners product automation
Goal:
- stop relying on heavy manual product curation for recommended products
- keep partner-linked recommendation candidates fresh automatically
- eventually replace the current utility-first Naver-result bridge as the main operator-scalable external product source

What "done" should mean:
- there is a repeatable ingestion/update job instead of manual one-by-one operator work
- recommended product data can refresh on a schedule
- stale products can expire or be deprioritized automatically
- the operator still has a review/override path when automation picks poor candidates

Likely subproblems:
- define source queries / category seeds / keyword seeds
- fetch partner products on a schedule
- normalize / dedupe results
- compute freshness state and replacement policy
- separate automated candidates from hand-picked operator choices

Current bridge state on 2026-05-22:
- Explore is stable enough to pause feature development until Coupang/API work resumes
- filtered Naver Shopping utility results remain the temporary live bridge
- operator can now turn Naver-result exposure on/off directly from admin, default ON, without an app rebuild

### 3. AdMob integration verification
Goal:
- confirm the Google AdMob integration is not only configured but actually trustworthy in release/runtime behavior

What "done" should mean:
- app init path is verified on real release surfaces
- correct platform app IDs / unit IDs are in use
- banner request / load / no-fill / impression / click paths are observable
- operator can tell whether low revenue is a traffic problem, fill problem, or config problem

Minimum verification areas:
- SDK initialization
- slot-to-unit mapping
- request success/failure logging
- impression event flow
- click flow
- region/platform/version visibility where helpful

### 4. Direct banner ad design guide
Goal:
- define a consistent creative/design rule set for Cartly's own direct ad banners

What "done" should mean:
- each banner slot has recommended dimensions and safe-area guidance
- visual style fits Cartly's calm grocery-decision-partner brand, not flashy sale spam
- operator knows acceptable copy length, CTA style, and image treatment
- admin upload flow can eventually show slot-aware design guidance

Important brand rule:
- direct ads should not turn Cartly into a loud coupon or commerce-feed app
- banners should feel relevant, restrained, and trustworthy

## Recommended execution order

### P0. Scheduled push
Reason:
- smallest path to real operator value
- immediately usable weekly habit loop
- least dependent on outside partner complexity

### P1. AdMob verification
Reason:
- monetization correctness should be verified before scaling ad traffic assumptions
- prevents false confidence from "configured" but unverified ad runtime

Current verification snapshot (2026-05-21):
- platform app IDs are present with real production values on both surfaces:
  - Android app ID: `ca-app-pub-7326648056182385~9903617195`
  - iOS app ID: `ca-app-pub-7326648056182385~1227671006`
- `app-ads.txt` is publicly exposed at `https://scan-api.seoa-nas.com/app-ads.txt`
- iOS release ad unit IDs are mapped to real Cartly units in `lib/services/admob_service.dart`:
  - banner: `ca-app-pub-7326648056182385/6115570564`
  - interstitial: `ca-app-pub-7326648056182385/3149023690`
  - rewarded: `ca-app-pub-7326648056182385/3972622950`
- Android release ad unit IDs are set to Cartly production values in `lib/services/admob_service.dart`:
  - banner: `ca-app-pub-7326648056182385/7877427532`
  - interstitial: `ca-app-pub-7326648056182385/2241957474`
  - rewarded: `ca-app-pub-7326648056182385/5798059103`
- lightweight runtime telemetry was added so the app records `admob_*` lifecycle events through `/v1/events` for init, load/fail, impression, click, show, dismiss, and reward callbacks
- AdMob console app approval mail arrived for iOS, and operator-side real-device validation confirmed live ad display on iPhone across the exposed banner/interstitial/rewarded paths
- operator can now distinguish configuration mistakes from post-approval traffic/impression lag, because the stack has moved past "configured only" into actual device-verified serving

Immediate next action for this workstream:
- watch AdMob reporting accumulate real impressions/revenue after the newly verified iOS serving window, then start populating Cartly's direct-banner inventory with operator-uploaded campaigns

### P2. Direct banner design guide
Reason:
- operator-safe direct ad execution needs design rules before banner inventory is used aggressively
- good guide reduces noisy brand drift and low-quality creative uploads

Current progress snapshot (2026-05-21):
- first practical design guide draft is now written at `docs/02_product/direct-banner-design-guide.md`
- first Cartly-aligned house-style mockups were created for real slot shapes:
  - `docs/02_product/direct-banner-examples/save-complete-soft-benefit.svg`
  - `docs/02_product/direct-banner-examples/saved-inline-contextual-grocery.svg`
  - `docs/02_product/direct-banner-examples/my-perks-member-benefit.svg`
- current recommendation is to use the shipped inline promo shell as the visual ceiling: soft warm surface, light border, compact visual tile, short helper copy, small pill CTA
- operator/runtime policy is now stricter: all current direct-banner slots are treated as `full_banner`, legacy campaign data was backfilled accordingly, and the Flutter-side rendering alignment is now carried through the current `1.0.8 (18)` iOS review build plus Android `1.0.8 (47)` tester tracks
- the immediate Explore follow-up wave and later customer-update wave have now settled into the current `1.0.8` line, which also carries the app-side admin-truth restoration for section/order behavior, `activeShopping` recommendation exposure, cleaned customer-facing `대안상품 보기` detail output, and the pending-scan persistence / duplicate-suppression reliability fix
- 2026-05-29 기준 release packaging work is effectively done for this wave: iOS `1.0.8 (18)` is in `WAITING_FOR_REVIEW`, Android `1.0.8 (47)` is aligned on internal/alpha, and operator focus can now move back to ongoing operations/growth work

Immediate next action for this workstream:
- surface the slot-aware size / safe-area guidance inside admin upload UX so operator uploads can be reviewed against the same house style before publish

### P3. Coupang automation
Reason:
- highest system complexity
- likely needs the most backend/admin/runtime design work
- should be designed after the operator model for push/ads is clearer

## Suggested first slice

Start with **scheduled push**.

First implementation target:
1. inspect current push campaign model + admin push routes
2. decide recurring-model shape
3. add one recurring weekly schedule for Friday 18:30 KST
4. add operator controls for enable / pause / edit
5. verify with a dry-run or test target before broad rollout

Result:
- steps 1-4 are now implemented in code
- live runtime has also been refreshed and the weekly Friday 18:30 KST schedule is now enabled with the baseline message
- remaining validation is observational: confirm the scheduled fire path on the next real slot or with a controlled manual-send check

## Non-goals for this document

- Android closed-test recruiting logistics
- one-off release submission checklists
- public marketing copy drafts

Those can live elsewhere or stay in chat when lighter-weight.
