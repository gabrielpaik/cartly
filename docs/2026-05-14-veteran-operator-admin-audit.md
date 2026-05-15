# Cartly Admin Veteran Operator Audit

Date: 2026-05-14
Status: draft working note

## Why this note exists

This note translates the live admin audit into operator-facing redesign guidance.

The goal is not generic UI polish.
The goal is to make each page answer the real operational question faster.

## Page role definitions

### Content
- role: operator-friendly structured editor
- optimize for: predictable edit scope, stable save behavior, clear preview linkage
- avoid: turning it into a campaign console or action-heavy triage board
- latest enforcement: My page compliance/support copy should stay in Content as screen-scoped fields, but the presence of the My footer card itself should not be operator-removable
- latest enforcement: privacy policy access should be permanently reachable in-app, while contact/business values remain operator-editable because they are operational data that can change

### Explore
- role: decision console
- optimize for: mode-separated operating decisions by user/app state
- avoid: blending recommendation pool work, rule tuning, preview, and state logic into one mixed surface

### Push
- role: campaign console
- optimize for: compose, reuse, target, send, review blockers

### Ads
- role: placement + performance console
- optimize for: knowing what is live, where it renders, how it performs, and what to stop/increase next
- avoid: acting like a slot-edit form without performance context

### Users
- role: customer DB + segmentation console
- optimize for: target extraction plus per-user lifecycle understanding
- avoid: being only a filter/export page

### Carts
- role: saved-result evidence console
- optimize for: understanding what users actually saved and what that implies for Explore/content operations

### Scan Ops
- role: evidence + triage console
- optimize for: result quality, queue health, failure correction, operator feedback loop
- avoid: becoming a raw failure log viewer

### Config
- role: runtime control console
- optimize for: safe operator decisions using plain runtime language
- avoid: exposing developer-oriented phrasing as the primary operating language

---

## Highest concern right now: Ads

The current Ads page is structurally better than before, but still not confident enough for a veteran operator.

The missing confidence questions are:
- what is live right now
- where exactly does it render
- what variant is tied to what slot and period
- how is it performing
- what should be stopped, replaced, or expanded

### Ads P0 redesign target

The page should answer those questions through 3 coordinated views.

#### 1. Exposure map
Top layer should show:
- slot
- surface
- placement position
- live creative
- reserved creative
- status
- schedule window
- last update

This is the truth table for runtime exposure.

#### 2. Selected slot workspace
For one selected slot, show:
- current live creative summary
- next reserved creative summary
- scheduling controls
- preview by actual surface shape
- save/publish actions

This is the action layer.

#### 3. Performance summary
For slot and creative performance, show:
- impressions
- clicks
- CTR
- downstream action if available
- date range comparison
- underperforming slots
- no-data slots

This is the decision layer.

### Ads current-state contract audit

What already exists in runtime today:
- `GET /admin/ads/slots`
  - returns slot identity, placement type, status, config, live/reserved campaign ids, and updatedAt
- `GET /admin/ads/campaigns`
  - returns campaign rows with lifetime impressions, clicks, and CTR aggregated per campaign
- `POST /admin/ads/campaigns`
  - appends a new campaign row and rejects duplicate / overlapping windows for the same slot
- `PUT /admin/ads/campaigns/{campaignId}`
  - edits an existing campaign row in place
- `POST /admin/ads/campaigns/{campaignId}/cancel`
  - retires a campaign row without deleting history
- `POST /v1/ads/impressions`
  - tracks `slotKey`, `campaignId`, optional `screenName`, and optional `creativeId`
- `POST /v1/ads/clicks`
  - tracks click by `impressionId`

What is still missing for operator confidence:
- creative-level grouping that is stable across campaign replacements
- downstream action signal after click
- clear surface labels that remain readable without opening the editor
- better cleanup rules for legacy rows that still have open-ended `startAt/endAt` gaps from the old slot-config era

### Ads P0 page shape

#### Header summary strip
- live slots
- reserved pending
- active creatives
- low CTR slots
- no-data slots

#### Top operator strip
- date range
- slot filter
- surface filter
- status filter
- variant filter
- performance view toggle

#### Main body
Left / center:
- exposure inventory table

Right / lower selected area:
- campaign-row setup sheet
- append row first, editable saved rows below
- current / next derived from time windows instead of fixed live/reserved pair fields
- live/reserved preview
- recent campaign history
- guided import popup with `양식 받기` + file select instead of naked file input
- slot-aware banner upload popup that shows recommended asset sizes before upload

Lower decision area:
- performance table by slot
- performance table by creative
- `needs review` list

### Ads P0 screen contract

#### A. Exposure inventory table
Required columns:
- slotKey
- surfaceLabel
- placementLabel
- slotStatus
- effectiveRuntimeState
- liveCreativeTitle
- livePeriod
- reservedCreativeTitle
- reservedPeriod
- lastUpdatedAt
- impressions
- clicks
- ctr
- downstreamActions if available
- reviewFlag

Behavior:
- row click selects slot workspace
- current performance range is reflected directly in row metrics
- `reviewFlag` is derived and color-coded: `ok`, `low_ctr`, `no_data`, `inactive_gap`, `reserved_mismatch`
- exact same slot + exact same time window rows may coexist as one serving group; partial overlaps are still blocked
- same-window groups use persisted `sortOrder`; numeric order means ordered carousel, and `999` grouped rows mean random rotation mode for app runtime

#### B. Selected-slot workspace
Required blocks:
- slot identity card
- live creative editor
- reserved creative editor
- actual surface preview
- recent campaign history
- publish/save actions

Behavior:
- live and reserved editors stay in one workspace, but surface identity stays pinned at top
- preview should always render the real slot shape, not a generic banner card
- history list should show prior live/reserved rows with status, period, impressions, clicks, CTR

#### C. Performance zone
Required blocks:
- slot performance table
- creative performance table
- review queue

Slot performance table columns:
- slotKey
- surfaceLabel
- liveCreativeTitle
- impressions
- clicks
- ctr
- downstreamActions
- lastImpressionAt
- decisionHint

Creative performance table columns:
- creativeKey
- title
- slotCount
- impressions
- clicks
- ctr
- downstreamActions
- firstSeenAt
- lastSeenAt

Review queue buckets:
- no data after exposure start
- low CTR
- expired live creative still attached
- reserved creative missing schedule
- clicks present but downstream missing

### Ads API contract for P0

#### Keep as-is
- `GET /admin/ads/slots`
- `PUT /admin/ads/slots/{slotKey}`
- `GET /admin/ads/campaigns`
- `POST /v1/ads/impressions`
- `POST /v1/ads/clicks`

#### Add
- `GET /admin/ads/performance/summary`
  - query:
    - `periodFrom`
    - `periodTo`
    - `slotKey?`
    - `surface?`
    - `status?`
    - `variant?`
  - returns:
    - `summary`
    - `slotRows[]`
    - `creativeRows[]`
    - `reviewQueues`
- `GET /admin/ads/slots/{slotKey}/workspace`
  - returns:
    - `slot`
    - `liveCampaign`
    - `reservedCampaign`
    - `history[]`
    - `performance`

The page can ship in one endpoint if needed, but these two response shapes are the minimum operator contract.

Implementation checkpoint on 2026-05-15:
- admin setup now uses a structured landing contract instead of relying on `internal:*` targetUrl encoding for new edits
- app-config now emits grouped `creatives[]` plus `rotationMode`, while still keeping legacy single-creative top fields for compatibility
- Flutter inline promo runtime now consumes grouped creatives, rotates them as ordered carousel or random group, and routes taps through the structured landing contract

### Ads data requirements

To become reliable, Ads needs stable data contracts for:
- slot identity
- surface identity
- placement identity
- creative identity
- active time window
- effective runtime state
- impression count
- click count
- CTR
- downstream event count if trackable

Recommended field rules:
- `slotKey` remains the immutable runtime placement id
- `surfaceLabel` is human-readable and derived from `screen + position + placementNote`
- `creativeKey` must be stable across repeated campaign snapshots when the creative is materially the same
- `effectiveRuntimeState` must be computed, not hand-entered
- performance metrics must be range-aware, never ambiguous between lifetime and filtered period values

If these are missing or fuzzy, operators will keep feeling uncertainty even if the layout looks better.

### Ads operator outcomes

A veteran operator should be able to do these in under 30 seconds:
- confirm what is currently live in a slot
- see whether a reserved creative is queued correctly
- identify which slots have no usable data
- identify which slots have weak CTR
- decide what to stop, replace, or leave alone

### Ads P0 implementation checklist
- split current page into exposure inventory, selected-slot editor, and performance summary zones
- add explicit columns for live creative and reserved creative in the inventory table
- add surface/placement labels that are readable without opening the editor
- add performance summary cards and low-signal / no-signal warning rows
- treat no-data and low-CTR states as first-class operator queues, not buried analytics
- mark current `/admin/ads/campaigns` metrics as lifetime campaign metrics until range-aware summary APIs land
- add a first-pass downstream signal placeholder even if initial value is `null` or `not_tracked`

### Ads delivery order
- P0.1: expose performance summary API and review queue logic
- P0.2: wire exposure inventory columns and selected-slot workspace to the new summary data
- P0.3: add creative-level grouping and downstream signal once runtime tracking exists

---

## Explore redesign target

Explore now needs mode separation more than generic compacting.

### Required mode model
- activeShopping
- postSave
- idlePlanning
- storeContext

### Explore P0 direction
- fixed mode rail or state switcher that never becomes visually ambiguous
- separate work modes for:
  - recommendation pool
  - decision rules
  - decision copy
  - preview
- selected mode context should persist across the page
- bulk upload/review actions should be visually grouped away from state decision controls

### Explore P0 page shape

#### Header summary strip
- active mode
- last saved
- runtime source state
- unsaved change state
- preview freshness

#### Left mode rail
- activeShopping
- postSave
- idlePlanning
- storeContext

This should remain visible while the operator changes tabs or subtasks.

#### Top work-mode strip
- recommendation pool
- decision rules
- decision copy
- preview

This is not the same thing as app mode. It is the task mode inside the selected app state.

#### Main body
Left / center:
- task-specific table or matrix

Right:
- selected-mode context
- selected object detail
- preview frame locked to current mode

### Explore data requirements
- stable mode key for each app state
- stable rule namespace per mode
- recommendation entry state per mode where relevant
- preview scenario binding that matches the selected mode exactly
- last updated / source-state visibility for each operator change surface

### Explore operator outcomes
A veteran operator should be able to do these in under 30 seconds:
- tell which app mode they are editing
- adjust one rule without wondering if it affects another mode
- inspect recommendation inventory for the selected mode only
- preview the currently selected mode without mental translation
- move between pool/rules/copy tasks without losing mode context

### Explore P0 implementation checklist
- add a persistent mode rail that never scrolls away from the task context
- separate task-mode tabs from app-state mode selection
- show selected mode in header, meta strip, and preview label at the same time
- make bulk upload/review controls visually secondary to the current mode context
- prevent mixed-state editing surfaces where rules, pool rows, and preview context look equally global

### Success condition
An operator should never wonder:
- which app state they are editing
- whether a rule belongs to the current mode
- whether the preview reflects the selected mode

---

## Users redesign target

Users is already useful as a segment console.
The next gap is customer understanding.

### Users P0 direction
Keep segmentation, then add per-user DB depth:
- lifecycle state
- member/guest transition state
- recent session timeline
- scan activity summary
- cart activity summary
- push reachability / ready devices
- operator note / action context if needed later

### Users P0 page shape

#### Header summary strip
- filtered users
- reachable push users
- members / guests
- active recently
- users with carts
- users with scans

#### Top operator strip
- account type
- query
- activity filters
- behavioral filters
- push readiness filter
- export / handoff actions

#### Main body
Left / center:
- customer table for the current segment

Right or modal drilldown:
- customer profile summary
- lifecycle state
- recent activity timeline
- cart summary
- scan summary
- push/device summary
- operator action suggestions

### Users data requirements
- stable user identity and guest/member relationship view
- last seen and recent session aggregates
- saved cart aggregates and last cart activity
- scan aggregates and last scan activity
- push-ready device counts and platform split
- drilldown timeline feed or recent-event summary per user

### Users operator outcomes
A veteran operator should be able to do these in under 30 seconds:
- extract a targetable segment
- understand why this segment matters
- open one user and understand their recent lifecycle/activity shape
- decide whether they are reachable by push right now
- infer whether they behave like a retained member, active guest, dormant user, or noisy low-value edge case

### Users P0 implementation checklist
- keep the current segment-console grammar, but add a real per-user drilldown summary layer
- show lifecycle and reachability signals directly in the main result table
- make customer drilldown answer cart, scan, push, and recency questions without leaving the Users area
- prepare a one-click handoff path from segment result to Push once the customer DB view is stable
- keep legacy cleanup adjacent but clearly secondary to customer understanding and targeting

### Success condition
The page should answer both:
- who should I target
- what kind of customer is this

---

## Carts / Scan Ops redesign target

These two pages should become the evidence loop that feeds Explore decisions.

### Carts P0 direction
- top insights should emphasize merchant/category/product patterns
- category correction should stay attached to visible evidence
- receipt-linked merchant data should be easy to scan
- operators should be able to infer what users are actually buying/saving now

### Scan Ops P0 direction
- top triage strip should emphasize worker health, failures, quarantine, feedback correction
- insight area should help identify product/category drift and result-quality changes
- queue actions should remain close to job rows
- detail modal should remain the place for deep correction history

### Success condition
These pages should let operators do two things at once:
- analyze what is happening in the result DB
- immediately correct what is going wrong

---

## Config redesign target

Layout is now acceptable.
Language is the next problem.

### Config P0 direction
Replace developer-oriented phrasing with operator-oriented runtime language:
- current state
- risk level
- who should act
- whether the operator can safely change it now

### Success condition
An operator should understand:
- what this setting affects
- whether the current state is healthy
- whether they should change it now
- what could break if they do

---

## Recommended implementation order

### P0
1. Ads confidence redesign
2. Explore mode separation
3. Users customer DB strengthening

### P1
4. Carts / Scan Ops evidence-loop strengthening
5. Config operator language rewrite

### P2
6. Content structured-editor refinement, without forcing it into campaign-console grammar

---

## Final rule

Do not optimize for “pages that look similarly compact.”
Optimize for “pages that let an operator answer the page’s core question immediately.”
