# Cartly Admin Operator Console

Last updated: 2026-05-18
Status: canonical admin/operator document

## Role of this document

This is the standalone current document for Cartly admin direction.
It replaces the need to reconstruct state by reading old proposal, audit, and checkpoint handoff notes in sequence.

## Core principle

Cartly admin should behave like an operator console, not a collection of long page-style forms.

Default grammar:
- browse in grid/table
- filter in compact horizontal strips
- edit selected items in a sheet/workspace
- keep runtime status/preview visible while editing
- verify against live-served runtime, not only source code assumptions

## Information architecture

Top-level grouping should remain operator-oriented:
- Dashboard
- App Experience
- Growth
- Operations
- System

The important durable decision is:
- **Operations is the completed baseline**
- **Growth is where the heavy relayout work was pushed and validated**

## Current accepted page roles

### Users
Role: customer DB + segmentation console

Accepted state:
- no longer a passive directory
- supports operator filtering and segmentation
- exports are Push-compatible by default
- region CRM / activity-region concepts were added for segmentation and targeting

### Push
Role: campaign console

Accepted state:
- compact operator shell is the baseline for untouched surfaces
- direct-upload audience workflow exists
- uploaded rows resolve server-side against live user/install/device state
- raw push tokens are not the primary targeting contract

### Ads
Role: placement + performance console

Accepted state:
- campaign rows are the source of truth, not slot `live/reserved` pair fields
- route-separated views are used instead of anchor-jump subnav
- table/workspace behavior is preferred over long card stacks
- targeting supports audience and normalized Korean region dimensions
- runtime selection is specificity-first

### Carts / Scan Ops
Role: operations baseline

These pages define the dense operator grammar reference:
- compact shell
- evidence/triage oriented structure
- table-first handling
- runtime/quality visibility over decorative layout

### Content / Config
Role:
- Content = structured screen/content editor
- Config = runtime control console

These should stay operator-friendly and predictable, not turn into campaign consoles.

## What was actually achieved

### Growth/admin relayout passes already landed
- Users segmentation console
- Push compact campaign console
- Ads row-based runtime model and denser operator treatment
- cross-page compact-shell alignment on multiple admin tabs

### Runtime discipline that must stay
- refresh live runtime after admin/public changes
- visually verify served pages rather than trusting source structure
- avoid Python 3.9-incompatible syntax in backend admin/router additions

## Public/business web tie-in

The public/business web is now adjacent to admin/runtime work because live content values can override fallback page copy.
That means public-site changes may require both:
- source updates
- live admin/runtime content alignment

## Canonical related files
- `docs/CURRENT_STATE.md`
- `docs/2026-05-11-cartly-admin-relayout-proposal.md`
- `docs/2026-05-14-veteran-operator-admin-audit.md`
- `admin-web/app/**`
- `backend/app/routers/admin_*.py`
- `backend/app/services/*admin*`
- `scripts/refresh-runtime.sh`

## What to stop doing
- do not treat old handoff/checkpoint docs as the primary source of truth
- do not revert to long page-style forms
- do not report page success before served runtime verification
- do not create new checkpoint-only docs when a current canonical doc can be updated instead

## Current next steps
1. Keep this document updated when admin/operator direction materially changes.
2. Use old checkpoint/audit docs only as historical references.
3. Prefer updating this document plus `CURRENT_STATE.md` instead of spawning new handoff notes for normal progress.
