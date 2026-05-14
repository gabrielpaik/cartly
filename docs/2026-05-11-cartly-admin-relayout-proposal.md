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
- Cart / Receipt copy inside Content now has a denser quick-entry strip for short item/receipt labels and actions, while longer validation/context copy stays in a sheet table
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

### Current implementation note
The Cart / Receipt subsection has now partially adopted this direction in code, but in a tighter operator form:

- short labels and CTAs like item name, price, save, receipt entry, and reminder count can sit in a dense quick-entry strip
- longer validation or receipt-context copy can stay in a lower sheet table
- this keeps the cart/receipt editor from feeling like a long one-field-per-row page when the operator is only tuning compact copy tokens

### Why this works
Operators think:
- "Home > Explore Entry 문구 바꾸자"
not
- "homeExploreEntryTitle key를 수정하자"

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
- after Push reaches a stable operator pattern, Ads should inherit the same Growth grammar

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

---

## 6. Scan Ops

Scan Ops should not be organized like a failure log viewer.
It should be a queue-and-result operations surface.

### Role

The default question should be:
- what jobs are moving through the queue
- what result did the customer actually see
- what category or correction action does the operator need to take

not:
- which raw stack trace should fill the whole screen

### Default layout

- top summary strip for queue, worker, feedback, failures
- compact queue control bar for filter, search, bulk category action, export
- main jobs table first
- row double-click opens a modal detail surface

### Main table priority

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

### Detail interaction

Job detail should open in modal form and carry:
- image
- lifecycle metadata
- customer-facing result or reviewed result
- failure history
- feedback history

This keeps the default page table-first while still allowing deep inspection.

### Feedback placement

`Recent Feedback` should not live as a detached hero card.
Feedback belongs in:
- queue summary counts
- row-level status context
- job detail history

### Category operations

Because Scan Ops is now also a correction surface, row-level and bulk category override should stay close to the jobs table.

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
