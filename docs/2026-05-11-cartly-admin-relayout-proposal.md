# Cartly Admin Relayout Proposal

Date: 2026-05-11
Status: draft for discussion

## Goal

Turn Cartly Admin from long page-style forms into a structured operator console built around:

- left navigation tree
- center data grid / list
- right detail sheet / drawer
- fixed live preview or runtime status panel

The reference style is inspired by legacy operations consoles, but Cartly should keep a cleaner and more modern information density.

---

## Current implementation status (2026-05-14)

The relayout is no longer just a proposal. Parts of it are already being applied in the admin web.

What is already moving in code:

- global admin IA has shifted toward `Dashboard / App Experience / Growth / Operations / System`
- Explore is already being treated as a workspace with tabbed operator surfaces instead of one long form
- Content has moved toward a compact operator header, dense sheet editing, and popup preview instead of a large inline preview block
- Scan Ops has moved toward a table-first queue view, with row double-click opening detail in a modal instead of keeping a confusing fixed detail card on the page
- feedback is being folded into queue summary and job detail context instead of living as a detached primary card

What this means for next work:

- do not revert to long page-style forms
- do not reintroduce large passive preview slabs when a compact preview control + popup is enough
- for operations pages, default to table first, then sheet or modal detail
- treat Operations as the completed baseline for this relayout pass, and use that grammar to reshape Growth next

---

## Core UX Principle

Current pain:

- too many long forms on a single page
- raw keys and runtime concepts are mixed together
- hard to tell where a value appears in app/admin/public
- hard to scan many entries quickly
- hard to edit one item deeply without losing context

Target shape:

1. Select domain in the left tree
2. Browse rows in a grid/list in the center
3. Edit selected item in a right-side sheet
4. Keep preview/status visible while editing

In short:

- browse in grid
- edit in sheet
- verify in preview

---

## Recommended Global Information Architecture

### Top-level nav groups

- Dashboard
  - Overview

- App Experience
  - Home
  - Explore
  - My
  - Login
  - Cart / Receipt

- Growth
  - Recommendation Picks
  - Push
  - Ads

- Operations
  - Users
  - Carts
  - Scan Ops

- System
  - Runtime Config
  - Integrations
  - Storage / Health

### Why this IA

The current nav is developer-oriented. The new nav should be operator-oriented.

Operators think in terms of:

- what part of the product they are operating
- what campaign or content they are managing
- what runtime/system issue they are checking

not in terms of backend module boundaries.

---

## Shared Page Layout Pattern

Every major admin screen should follow one of two layouts.

### Pattern A. Tree + Grid + Sheet + Preview

Use for pages with many entries and repeated editing.

Best for:

- Explore recommendation pool
- Push campaigns
- Ads inventory
- Content by screen/section

Layout:

- left: tree / category list
- center: grid/list/table
- right: detail sheet
- far right or sticky bottom-right: preview/status panel

### Pattern B. Section rail + Config sheet + Runtime panel

Use for lower-frequency structured settings.

Best for:

- Runtime Config
- Integrations
- Storage / Health

Layout:

- left: section rail
- center: grouped settings cards or matrix
- right: runtime status / live values / warnings

---

## Page-by-Page Proposal

## 1. Overview

### Role

Overview should not be a heavy edit page.
It should become the control tower.

### Layout

- top KPI strip
- left/main: alerts, queues, stale/fallback warnings
- right: quick actions and recent operator actions

### Blocks

#### A. Runtime Health
- backend
- admin
- preview
- app-config
- scan worker
- push
- storage

Each row shows:
- status
- last checked time
- stale/fallback badge
- quick action

#### B. Operator Alerts
Examples:
- live explore config unavailable
- preview using fallback data
- stale runtime after save
- scan worker down
- push credentials not ready

#### C. Quick Actions
- open Explore recommendations
- open Home copy
- run smoke
- refresh runtime
- open latest carts issue

#### D. Recent Changes
- latest runtime config edits
- latest explore updates
- latest content saves

### What to avoid
- long editable forms
- mixed content/runtime details inline

### Current direction update
- Overview now follows the same compact operator shell as Push: compact header, summary strip first, dense meta strip, then warning/detail cards
- the first visible layer should be operator signals and current-state metrics, not large decorative summary blocks
- detail clusters can stay below, but their spacing and card density should inherit the same compact console grammar

---

## 2. Explore

This should be the first page to redesign.
It has the clearest payoff and matches the reference layout best.

### Explore page tabs

#### Tab 1. Layout
Purpose: section order and state structure

Center panel:
- state selector: activeShopping / postSave / idlePlanning / storeContext
- rows for section order
- drag reorder
- enable/disable toggle

Right panel:
- live preview for selected state

#### Tab 2. Decision Matrix
Purpose: decision rules and priorities

Center panel:
- matrix table
- rows:
  - revisitRecentScanLimit
  - revisitCartItemLimit
  - revisitMaxItems
  - repeatMinCount
  - repeatMaxItems
  - offerMaxSlots
  - stateDecisionPriorities
  - stateDecisionMaxCounts
- columns:
  - activeShopping
  - postSave
  - idlePlanning
  - storeContext

Right panel:
- explanation for selected rule
- effect preview

#### Tab 3. Recommendation Pool
Purpose: operator-managed recommendation entries

This is where the reference screenshot maps most directly.

##### Left tree
- All items
- Enabled
- Needs review
- Missing thumbnail
- Missing price
- Coupang
- Naver
- 11st
- Hidden

##### Center grid columns
- visible
- type (URL / iframe / HTML)
- provider
- title
- price status
- thumbnail status
- deeplink status
- updatedAt
- sort/order

##### Row actions
- edit
- duplicate
- move up/down
- hide/show
- delete

##### Right detail sheet
- raw input
- parsed result summary
- title override
- price override
- thumbnail override
- deeplink
- disclaimer relation
- item preview card
- parse warnings

##### Preview panel
- actual Explore card rendering
- state scenario switcher

#### Tab 4. Preview
Purpose: full scenario preview

- activeShopping
- postSave
- idlePlanning
- storeContext
- mobile frame preview
- preview reload button

### Explore page top toolbar

- breadcrumb / current branch
- live or fallback badge
- unsaved changes badge
- preview reload
- runtime refresh
- save current tab

### Current direction update
- Explore should now be treated as a decision console, not just a dense settings page
- mode separation is mandatory because the live product already operates across distinct states like activeShopping / postSave / idlePlanning / storeContext
- the operator should always know which mode they are editing, which recommendation/result logic belongs to that mode, and what preview scenario is currently active
- recommendation pool operations, decision-rule tuning, and decision-copy editing should feel like separate tasks, not one blended mega-surface
- future refactors should bias toward explicit mode rails, selected-mode context, and bulk-operation strips that do not compete visually with state-level decision work

### Explore P0 target shape
- persistent left mode rail for activeShopping / postSave / idlePlanning / storeContext
- separate task strip for recommendation pool / decision rules / decision copy / preview
- selected mode should remain visible in header, meta strip, and preview at the same time
- preview should always be mode-bound, never visually ambiguous about which app state it reflects

### Explore implementation checkpoint
- served `/explore` keeps the workspace/task switch in the main sidebar and no longer repeats that task navigation inside the page body
- the page-local control is now a compact horizontal mode row placed directly under the summary/meta area, so mode remains easy to switch without creating a sidebar-inside-sidebar pattern
- the old right `Mode-bound preview` card was removed because it was mostly restating visible mode data rather than adding decision value
- recommendation / rules / copy / store workspaces remain the same underlying operators, but the shell now separates their roles more cleanly: sidebar for task, in-page row for mode, top actions for preview
- next Explore work should only bring preview back if it becomes a genuinely informative simulation, not a repeated status card

---

## 3. Content

Content should stop being a raw key list and become screen-based content operations.

### Left tree

- Home
  - Header
  - Current Cart
  - Add Section
  - Recent Scan
  - Explore Entry
  - Empty / Toast

- Explore
  - Header
  - Recommendation copy
  - Empty / Helper
  - Disclaimer

- My
  - Header
  - Member state
  - Guest state
  - Benefits
  - Monthly Summary
  - Saved History

- Login
  - Modes
  - Fields
  - Validation
  - Recovery

- Cart / Receipt
  - Cart Detail
  - Receipt Compare
  - Common actions

- Public Landing
  - Hero
  - Flow
  - Status
  - Partner section
  - Footer / privacy

### Center grid columns
- field label
- current value preview
- type (title/body/cta/helper/empty/toast)
- surface (app/admin/public)
- last updated

### Right detail sheet
- actual field edit
- char guidance
- connected screens
- live preview snapshot

### Current direction update
- Content should move forward as an operator-friendly structured editor, not as a Push-style campaign console
- the primary win is predictability: screen-based grouping, stable edit scope, clear preview linkage, and low-risk save behavior
- avoid turning Content into a hyper-dense action surface where many unrelated copy decisions compete at once
- operators should feel they are editing a known surface with controlled scope, not spelunking through raw field inventories or runtime internals

### Why this works
Operators think:
- "Home > Explore Entry 문구 바꾸자"
not
- "homeExploreEntryTitle key를 수정하자"

### My page compliance/footer contract (2026-05-15)
- My page bottom area should always expose an easy path to privacy and support information.
- The compliance/support section itself should be hardwired into the app surface, not removable by content operators.
- Current accepted UI direction is a compact gray inline footer, not a card.
- Privacy policy should open inside the app, and support email should stay as lightweight inline text/copy action.
- Operator-editable values should live in Content > My copy fields:
  - compliance section title/body
  - privacy policy label + URL
  - support email label + value
  - support note
- Runtime fallback should always keep a valid privacy-policy path even when admin fields are empty.
- Missing operator contact values should fail soft in app UI with a visible warning prompt rather than silently hiding the compliance area.
- Customer-facing location should not appear as a bottom history/sample section.
- If a latest location exists, show one compact secondary-text line below the account identity row and above the My body copy, with a manual refresh action.
- Preferred display shape is customer-friendly area text such as `양평동, 서울특별시에서 접속중`, while internal targeting/storage should continue to use normalized city/district/neighborhood keys and keep raw coordinates/history local/internal only.
- Future ads/explore targeting should use normalized city/district/neighborhood keys, not raw coordinates.

---

## 4. Runtime Config

Split product-runtime settings from infra/system.

### Tabs

#### Product Runtime
- My page runtime settings
- Explore feature flags
- receipt reminder delay
- section orders
- category groups

#### Integrations
- Coupang runtime override
- partner readiness
- push provider readiness

#### Storage / Paths
- storage root
- assets root
- branding dir
- ads dir
- compatibility state

#### Health / Smoke
- smoke history
- manual smoke trigger
- recent failures

### Recommended interaction
- left section list
- center grouped settings/matrix
- right runtime/live value panel

### Current direction update
- Runtime Config now shares the Push compact shell as well: compact header, summary strip, meta strip, then pane-driven operator surfaces
- pane switching should not introduce separate visual density rules; overview, smoke, runtime, my-page, and Coupang panes should all inherit the same compact console baseline
- my-page and Coupang should not fall back to tall one-column forms; keep operator controls grouped into compact subcards, with long JSON/note/history blocks visually secondary
- the next meaningful Config step is language, not layout: reduce developer phrasing, make state/risk/action clearer, and help operators know whether something is safe to change now, needs coordination, or is only informational
- avoid server/client pane mismatch for query-param-driven tabs; the served runtime must render the selected pane cleanly without hydration drift
- 2026-05-15 polish pass: overview, smoke, my-page, and Coupang wording were rewritten toward operator language, removing visible developer phrases like `effective enabled`, `admin override`, `Runtime & startup`, and `Public landing`

---

## 5. Push / Ads

Operations is now effectively the completed reference branch for this admin relayout.
The active next target is Growth.

These should use campaign/inventory tables instead of large forms.

### Push
Center grid columns:
- title
- target
- schedule
- status
- last sent
- deeplink

Right sheet:
- body
- audience
- deeplink
- test send
- schedule
- preview

Current direction update:
- Push should follow a campaign-table-first workflow
- recent campaign reuse should be easy from the main table
- device readiness should be reframed as delivery blockers / readiness support, not the primary hero surface
- the composer should behave like a right-side operator sheet, even if the first implementation still uses a responsive card layout
- preset-first composer flow is now preferred: choose preset, inspect selected result, then edit title/body first; advanced fields should stay collapsed unless needed
- direct audience upload is now part of the Growth operator grammar: accept userId/installId Excel or CSV, preview live-ready targets first, and avoid raw push-token upload
- 2026-05-15 follow-up: Push now also needs first-class CRM segmentation from server-side region activity, not only account type or upload sheets. The accepted Phase 2 grammar is `recent region / frequent region / primary activity region`, backed by customer region history + aggregate profiles rather than the anonymous runtime cache alone.

### Ads
Center grid columns:
- slot
- creative title
- status
- active period
- priority
- destination

Right sheet:
- asset preview
- title/body
- target slot
- period
- priority
- click target

Current direction update:
- Ads should move toward inventory-table and campaign-history grammar, not repeated large per-slot form blocks
- slot inventory, live/reserved state, and recent campaign history should be scannable before deep editing
- the next concrete Ads shape is now table first plus one selected-slot editing sheet, instead of rendering every slot as a full live/reserved editor stack at once
- live and reserved editing should behave like a horizontal operator sheet with one row per variant, while slot selection happens from a compact inventory table above
- after Push reaches a stable operator pattern, Ads should inherit the same Growth grammar
- the next veteran-level concern is confidence, not just layout: the operator must be able to answer "what is live now, where does it show, how is it performing, and what should I stop or increase"
- Ads should evolve into a placement-and-performance console with three first-class views: exposure map, selected slot editing, and slot/creative performance summaries
- efficiency data should not stay abstract; slot-level impressions, clicks, CTR, and downstream action signals should be visible in a way that supports keep/stop/replace decisions
- 2026-05-15 승인 후 방향은 더 명확해졌다: slot config의 `live + reserved` 1쌍 편집이 아니라 `campaign row`가 source of truth이고, runtime의 current / next는 시간창에서 파생 계산되어야 한다

### Ads P0 target shape
- top exposure inventory with live creative, reserved creative, slot, surface, position, status, updatedAt, and filtered-period metrics
- setup page should now collapse into one horizontally scrollable sheet where `slot` is the primary discriminator, the old separate slot-picker block is removed, and current / reserved operations are handled inline with immediate save/upload controls rather than oversized form cards
- lower efficiency zone with slot-level and creative-level summaries plus low-signal / no-signal review rows
- 2026-05-15 follow-up simplification: the explicit three-step operator flow remains, but it now lives as separate Ads routes under the main sidebar with short sublabels `현황 / 세팅 / 효율` instead of anchor jumps or a nested in-page rail, and the page body itself no longer wastes width on duplicate navigation
- 2026-05-15 implementation checkpoint: `/ads/setup` is now a true campaign-row sheet. Row 1 is append, saved rows are editable below, and overlap/duplicate validation is enforced by backend before runtime derivation.
- 2026-05-15 operator pass extension: the top-right actions are now compact fixed-width controls (`다운로드 / 업로드 / 양식 / 추가 / 삭제 / 저장`), setup import moved to a guided popup with `양식 받기`, and banner upload moved from immediate Finder open into a slot-aware popup that exposes recommended image sizes before file selection.
- 2026-05-15 runtime extension: landing is no longer treated as an `internal:*` string hack in `targetUrl` for new rows. Admin now writes structured `landingType + landingKey (+ landingParams)` metadata, and `/v1/app-config` now emits grouped `creatives[] + rotationMode` so same-window campaign groups can become ordered carousel or `999` random sets in the app runtime.
- 2026-05-15 targeting extension: campaign rows now also own exposure targeting fields. The backend still keeps legacy single-region fields (`targetCity`, `targetDistrict`, `targetNeighborhood`) for compatibility, but the current source-of-truth has moved to canonical multi-region keys (`targetRegionKeys` / `target_region_keys_json`) plus `audienceType` + `targetRegionLevel`. The setup sheet no longer depends on raw 시/구/동 typing; it now uses a Korea region picker with narrowed dropdowns, checkbox multi-select, compact in-cell summaries, bucket-scoped overlap validation, and specificity-first runtime matching.
- 2026-05-15 customer-context extension: `/v1/app-config` is no longer effectively anonymous for ads. The app now sends auth plus normalized region headers, the backend persists last-known city/district/neighborhood on the customer record, and ad slot derivation can resolve member/guest + 시/구/동 context from live request state instead of local-only app memory.

### Ads implementation contract

Current live contracts already available:
- `GET /admin/ads/slots`
- `PUT /admin/ads/slots/{slotKey}`
- `GET /admin/ads/campaigns`
- `POST /admin/ads/campaigns`
- `PUT /admin/ads/campaigns/{campaignId}`
- `POST /admin/ads/campaigns/{campaignId}/cancel`
- `POST /v1/ads/impressions`
- `POST /v1/ads/clicks`

What they already cover:
- slot identity and config
- campaign-row create/update/cancel as the operator source of truth
- runtime current / next derivation back into slot config for admin + app-config consumption
- campaign-level impressions, clicks, CTR
- runtime impression/click tracking
- structured landing metadata on campaign rows (`landingType`, `landingKey`, optional `landingParams`)
- grouped live creatives in app-config via `creatives[]` and `rotationMode`

What they do not yet cover cleanly:
- creative-level grouping that survives repeated copy swaps of the same concept
- downstream action signal after click
- creative-level grouped performance
- no-data / low-CTR operator queues
- downstream post-click action metrics

Recommended P0 additions:
- `GET /admin/ads/performance/summary`
  - returns header summary, slotRows, creativeRows, and reviewQueues for the selected date range
- `GET /admin/ads/slots/{slotKey}/workspace`
  - returns selected slot, live/reserved campaign summaries, history, preview metadata, and slot-scoped performance

### Ads exposure inventory columns
- slotKey
- surfaceLabel
- placementLabel
- slotStatus
- effectiveRuntimeState
- liveCreativeTitle
- livePeriod
- reservedCreativeTitle
- reservedPeriod
- updatedAt
- impressions
- clicks
- ctr
- downstreamActions if available
- reviewFlag

### Ads decision rules
- `reviewFlag=no_data` when a live or reserved-ready slot has zero impressions in the selected period after exposure start
- `reviewFlag=low_ctr` when impressions clear the minimum threshold but CTR is below the operator threshold
- `reviewFlag=inactive_gap` when the slot is active but no effective live creative exists
- `reviewFlag=reserved_mismatch` when reserved creative content exists without a valid schedule window
- all table metrics must reflect the currently selected date range, not hidden lifetime totals

### Users
Center grid columns:
- user
- segment metrics
- push readiness
- device / platform
- last active
- actions

Top operator bar:
- account type
- keyword search
- recent N-day visit filter
- visit count minimum
- scan count minimum / less-than
- saved cart minimum
- push-ready-only toggle
- export for push

Current direction update:
- Users should behave like a segment extraction console, not a passive account directory
- the first practical segment grammar is now based on actual live metrics already available in runtime: last seen, session count, scan count, saved cart count, and ready push devices
- quick presets like recent 7d / recent 30d / visit 5+ / scan 10+ / scan under 3 are useful because they match operator questions better than raw field-by-field filtering alone
- export should produce a Push-compatible sheet keyed by `userId` with `installId` left blank by default, because the backend should re-resolve live-ready devices during upload preview/send
- legacy cleanup stays adjacent, but should not dominate the primary Users surface anymore
- the next step is to strengthen Users as customer DB plus segmentation: lifecycle state, activity timeline, membership transition, push reachability, cart/scan behavior, and operator action context should become easier to inspect per person
- a strong Users page should answer both "who should I target" and "what kind of customer is this" without forcing operators into separate disconnected tools
- 2026-05-15 CRM extension: the data model should no longer pretend one user has one static region. Users can accumulate multiple activity regions, so the durable operator concept is `활동지역` history + aggregates, then a softer UI vocabulary like `최근 활동지역`, `상위 활동지역`, and `활동지역 수` instead of a single hard `지역` label.

### Users P0 target shape
- keep the current segment filter bar and segment result table
- add a per-user drilldown layer for lifecycle, recent activity, carts, scans, and push/device reachability
- surface customer state and reachability signals directly in the main result table so segmentation and customer understanding are not split apart

### Users implementation checkpoint
- served `/users` now keeps the segment console, but the result table also exposes lifecycle, reachability, and operator-action signals so targeting and customer understanding happen in one surface
- the per-user drilldown at `/users/{id}` now behaves more like a compact customer DB: profile, operator context, push reachability, recent activity timeline, scan summary, saved-cart summary, and event summary are available together
- the current backend source is no longer only ephemeral runtime evidence. Phase 2 now adds explicit user-region history/profile persistence so Users and Push can reason about multi-region behavior without collapsing everything into `last_region_*`.
- `/users` should now expose region activity directly in both filtering and result rows: recent/frequent/primary region segments, top activity-region summary, region-count context, and per-customer region drilldown.
- `/users/{id}` should now show region profiles plus recent region events alongside lifecycle, scans, carts, and push state.
- next Users work should deepen customer suggestions and cross-customer analysis, not revert to a plain directory or split customer-state inspection back into disconnected pages
- 2026-05-15 polish pass: the top filter bar now uses one horizontal compact row, recent-visit became a preset select, scan filtering was collapsed from separate min/lt blocks into one operator-plus-value control, and region activity filtering was added as a peer operator control rather than a detached submenu.

---

## 6. Carts / Scan Ops

Carts and Scan Ops should now be treated as the evidence and triage loop for Explore operations.
They are not just logs, and they are not just export pages.

### Shared role

The default questions should be:
- what result data is accumulating in runtime
- what pattern does that data suggest for Explore decisions
- what broke or degraded today
- what can the operator correct immediately

In short:
- accumulate evidence
- inspect patterns
- correct bad outcomes fast
- feed the next Explore operating decision

### Carts

Carts should operate as saved-result evidence, not only as a history viewer.

#### Primary jobs
- understand what users actually saved
- detect merchant/category/product patterns
- inspect receipt-linked outcomes
- identify cleanup/correction opportunities that affect downstream merchandising and Explore strategy

#### Recommended emphasis
- top summary strip for cart count, member/guest split, receipt coverage, average value, average items
- insight blocks for top merchants, top categories, top final items, and recent notable shifts
- filter/control row for time range, user type, category scope, receipt presence, and query
- table-first saved cart history
- category correction tools close to the visible result set, not isolated far away

#### Current direction update
- Carts should support both analysis and immediate intervention
- the operator should be able to move from observed pattern to category correction without leaving the page
- insights here should help explain what Explore should emphasize more, suppress, or revisit
- 2026-05-15 polish pass: the served filter bar was compacted into a single horizontal row with customer-type select plus date/query controls, replacing the larger tab-heavy search block

### Scan Ops

Scan Ops should not be organized like a failure log viewer.
It should be a queue-and-result operations surface.

#### Role

The default question should be:
- what jobs are moving through the queue
- what result did the customer actually see
- what category or correction action does the operator need to take

not:
- which raw stack trace should fill the whole screen

#### Default layout

- top summary strip for queue, worker, feedback, failures
- compact queue control bar for filter, search, bulk category action, export
- main jobs table first
- row double-click opens a modal detail surface

#### Main table priority

Columns should bias toward:
- image
- status
- job / user / device
- primary result
- category override
- customer message
- latest operational log
- createdAt
- action

Failure detail still matters, but it should be downstream context, not the main organizing surface.

#### Detail interaction

Job detail should open in modal form and carry:
- image
- lifecycle metadata
- customer-facing result or reviewed result
- failure history
- feedback history

This keeps the default page table-first while still allowing deep inspection.

#### Feedback placement

`Recent Feedback` should not live as a detached hero card.
Feedback belongs in:
- queue summary counts
- row-level status context
- job detail history

#### Category operations

Because Scan Ops is now also a correction surface, row-level and bulk category override should stay close to the jobs table.

#### Current direction update
- Scan Ops should simultaneously support insight reading and immediate triage
- failure, quarantine, worker health, and feedback correction signals should rise to the top when they need action
- the page should help operators decide what Explore needs more of, what OCR/result quality is degrading, and what should be corrected right now before the next batch compounds the issue

---

## Shared UI Rules

### 1. Show labels first, raw keys second
Raw keys should be hidden under advanced details.

### 2. Every row should show scope
Examples:
- App runtime
- Public landing
- Admin only
- Preview only

### 3. Every page should show source state
Examples:
- live
- fallback
- mock
- env override
- runtime override

This is critical. Many current admin confusions come from not knowing which source won.

### 4. Save should be local, not giant-page global
Preferred:
- save this section
- save this tab
- save selected entry

Not preferred:
- one giant page save after many unrelated edits

### 5. Preview should stay visible
Preview should be sticky or fixed for the selected domain.

---

## What to Borrow from the Reference Screenshot

Keep:
- left hierarchical tree
- center operational table/grid
- row-driven workflows
- obvious current-location context
- batch or row actions

Do not copy directly:
- extreme information density
- too many tiny buttons in one line
- old ERP visual heaviness
- weak spacing and cramped typography

Cartly should feel:
- operational
- structured
- modern
- readable

---

## Recommended Implementation Sequence

### Phase 1
Explore remains the primary pilot.

Deliver:
- new Explore page IA
- tabs: Layout / Decision Matrix / Recommendation Pool / Preview
- recommendation pool as grid + right sheet
- sticky preview

### Phase 2
Content follows with the same operator grammar, but in a denser form.

Deliver:
- screen-based content tree
- compact header actions that merge section, save, and preview control where possible
- sheet-style field editing
- popup-linked preview instead of a large inline preview block

### Parallel operations track
Scan Ops should evolve alongside Explore and Content, because it is the main operator-facing queue surface.

Deliver:
- queue-first summary + control bar
- result/category-centered jobs table
- modal detail on row double-click
- feedback folded into queue and detail context

### Phase 3
Redesign Runtime Config.

Deliver:
- product runtime vs infra split
- better source-of-truth visibility

---

## Explore Wireframe Draft

### Header row
- breadcrumb: App Experience / Explore
- environment badge: live or fallback
- unsaved badge
- preview reload
- runtime refresh
- save

### Body

#### Left rail
- Layout
- Decision Matrix
- Recommendation Pool
- Preview

#### Center area (Recommendation Pool active)
Toolbar:
- search
- provider filter
- status filter
- add item
- bulk hide
- bulk delete

Grid:
- checkbox
- visible
- provider
- input type
- title
- price
- thumbnail
- deeplink
- updatedAt
- actions

#### Right sheet
Sections:
1. Raw input
2. Parsed output
3. Manual overrides
4. Card preview
5. Diagnostics

#### Far right or sticky bottom-right
- mobile app preview
- scenario selector

---

## Key Recommendation

Start with Explore as the pilot.

Why:
- highest current complexity
- strongest fit to tree + grid + sheet pattern
- recommendation pool naturally benefits from row operations
- immediate operator value

If Explore works, the same design language can expand to Content and Config.

---

## 2026-05-17 operator follow-up

The active pre-ship operator follow-up for build 24 is now implemented and refreshed into the live-served admin runtime.

What landed:
- admin-editable runtime copy coverage for the new member `수정 및 가족공유` page, including profile, password, household/share, and account-deletion confirm/done/fail strings
- admin Users detail now exposes household/share runtime state, member list, invite-code summary, and operator actions for `Disconnect user` and `Disband household`
- admin Users list now carries household-state summary data for row-level visibility (`solo` vs share role/member count)

Verification completed in this pass:
- backend `py_compile` passed for the admin copy and admin users changes
- Flutter analyze passed for the My/settings-household copy wiring
- `admin-web` production build passed
- runtime refresh completed successfully
- public live-served admin screenshots confirmed:
  - `/content?section=account` shows the new My/settings/share and account-deletion copy fields
  - `/users/[id]` shows household/share summary, operator controls, and member list
- destructive operator household actions were **not** executed against live user data during verification; instead, the disconnect/disband service logic was smoke-tested against a temp SQLite DB fixture and passed

Ship gate status:
- the earlier build-24 blocker for admin content + admin Users household/operator visibility is now cleared
- next safe step is to prepare the release commit / build bump and ship `1.0.4 (24)` when ready
