# Cartly Admin Growth Checkpoint Handoff

Date: 2026-05-14
Status: active checkpoint

## Why this note exists

This note is a checkpoint and handoff snapshot for the current Cartly admin workstream.

The main reason to record it now is:

- the admin runtime briefly hit a client-side exception / access scare on the public domain
- the current worktree has become large enough that Seungdae wanted a commit boundary now
- the Obsidian raw_docs layer should keep an explicit narrative of what was actually approved, what is live-verified, and what still needs cleanup

## Confirmed approved direction

The confirmed active direction is admin-side hardening and relayout, especially around the Growth and Operations operator surfaces.

What was clearly approved and progressed:

- Users is no longer just a directory, it is now a segment extraction console
- Push now supports direct-upload audience input and live device-state re-resolution
- Users export is intentionally Push-compatible by default
- Operations surfaces like Carts and Scan Ops are the baseline operator-console grammar to carry forward
- Growth work should continue from Push into Ads, not drift back into random page-level restyling

## Live-verified state at this checkpoint

### Users
- `/users` is operating as a live-backed segment extraction console
- filters include account type, recent activity, visit count, scan count min / less-than, saved-cart minimum, and push-ready-only
- `Export for Push` emits a userId-based audience sheet for the Push upload flow

### Push
- `/push` is live with the tighter operator console grammar
- direct-upload audience flow is implemented
- uploaded rows are resolved server-side against live user / install / device state
- send flow does not accept raw push tokens as the primary targeting contract

### Ads
- `/ads` has a first-pass inventory surface in place
- it still has structure debt relative to the newer Push / Users grammar
- the next meaningful Growth refactor target is still Ads, especially table + selected-slot editing flow

### Operations baseline
- Carts and Scan Ops are functioning as the baseline reference for dense operator surfaces
- receipt-linked cart insights and scan queue/operator patterns are part of the current reference shape

## Runtime incident at this checkpoint

A public admin access scare happened during this work window.

Observed symptom:
- `cartly-admin.seoa-nas.com` intermittently showed a client-side exception / access failure report from the browser side

What was checked:
- local and public admin both still had HTML responses
- current Next asset hashes matched the served bundle
- route-level verification succeeded for overview, content, users, push, ads, carts, and scan-ops
- a clean runtime reset was then executed to reduce stale-process / stale-client risk

Clean reset result:
- admin listener restarted cleanly
- backend health returned OK
- public and local login paths returned 200
- public `/overview` re-verified without client-side exception banner

## Important caution

A wrong detour happened during this session.

What happened:
- after Seungdae clarified that the workstream was admin-only, not Flutter app UI work, a wrong intermediate path still happened
- Flutter-side receipt/cart density edits were touched briefly, then reverted
- after that, an additional wrong detour modified the admin Content surface (`/content`) instead of staying strictly on the intended operator workstream

How to treat it:
- this checkpoint should not be read as approval for broad Content relayout work
- if Content-side compacting appears in the current worktree, treat it as a review / rollback candidate unless Seungdae explicitly re-approves that surface
- the real approved spine remains Users -> Push -> Ads and the broader admin operator relayout

## Recommended next step after this checkpoint

1. Reconfirm whether any Content-surface detour should remain or be rolled back
2. Return to Ads and complete the stronger table + selected-slot editor/sheet grammar
3. Optionally add a Users -> Push one-click handoff so filtered live segments can move into Push without file download/upload
4. Keep updating the relayout proposal and syncing raw_docs after major admin milestones

## Files/work areas that define this checkpoint

Key repo areas in play:
- `admin-web/app/users/page.tsx`
- `admin-web/app/push/page.tsx`
- `admin-web/app/ads/page.tsx`
- `admin-web/app/carts/page.tsx`
- `admin-web/app/scan-ops/page.tsx`
- `backend/app/routers/admin_push.py`
- `backend/app/routers/admin_users.py`
- `backend/app/services/push_service.py`
- `backend/app/services/admin_user_service.py`
- `docs/2026-05-11-cartly-admin-relayout-proposal.md`
- `scripts/sync_raw_docs.py`

## Commit intent

This checkpoint is meant to create a stable commit boundary so the current admin progress and runtime recovery state are not left floating in a large uncommitted worktree.
