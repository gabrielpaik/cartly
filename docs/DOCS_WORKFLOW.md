# Cartly Docs Workflow

Last updated: 2026-05-18
Status: canonical docs-process note

## Goal

Do not force future readers to reconstruct state by chaining multiple handoff/checkpoint notes together.

## Canonical docs

### 1. `docs/CURRENT_STATE.md`
Use for:
- current product/runtime/release/public-site state
- what is live now
- what is shipped now
- what is still open now

### 2. `docs/ADMIN_OPERATOR_CONSOLE.md`
Use for:
- admin relayout direction
- accepted operator-console grammar
- durable admin IA/page-role decisions

## Reference docs
Keep long-lived reference docs when they still have standalone value, for example:
- architecture
- design guide
- frontend spec
- contracts
- runbooks

## Archive docs
Time-bound checkpoint/handoff/prep notes should move under:
- `docs/archive/YYYY-MM/`

They are historical references, not the primary source of truth.

## Obsidian latest-only rule
- Obsidian working folders should keep **latest canonical files** as the active reading set.
- Superseded notes should not compete with current-state docs in the main reading path.
- Older notes should be moved into a simple archive/old area, which for the current Cartly raw-doc sync structure maps to `08_Archive/`.
- Archive is for storage, not for default reading order.

## Update rule
When work materially changes state:
1. update `CURRENT_STATE.md`
2. update `ADMIN_OPERATOR_CONSOLE.md` if admin/operator direction changed
3. only create a new checkpoint note if a historical snapshot is genuinely useful
4. archive that snapshot instead of leaving it in the top docs root

## Practical rule of thumb
If a doc requires another doc to understand current reality, it should not be a top-level current-state doc.
Top-level current-state docs should be readable on their own.

## Release-doc rule
- The release docs cleanup must preserve the new operating rule: iOS TestFlight and Android internal testing move together by default, and final platform approval/submission also moves together unless the user explicitly chooses a split rollout.
