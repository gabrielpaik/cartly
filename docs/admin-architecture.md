# WIMC Admin architecture v1

## Goal

Create a separate admin web console for operating WIMC as a commercial product.

This admin is not a developer-only panel. It should support:
- KPI monitoring for CMO/CFO
- user and account operations
- scan pipeline monitoring for CTO/ops
- ad slot and monetization visibility
- clean, readable information architecture for CDO

## Product positioning

Admin is a backoffice product with 3 simultaneous jobs:
1. **Executive dashboard** — see growth, usage, monetization, retention
2. **Operations console** — inspect users, sessions, scan jobs, failures
3. **Control plane** — manage ad slots, feature flags, possibly experiments later

## Recommended stack

- Frontend: **Next.js**
- UI: React + component library (keep clean and dashboard-oriented)
- Charts: lightweight chart layer for KPI cards + trend lines
- Backend: reuse WIMC API + add `/admin/*` endpoints
- Auth: admin-only role-based access

## Admin app sections (IA)

### 1. Overview Dashboard
Primary audience: CMO, CFO, CEO

Cards:
- DAU
- WAU
- MAU
- active users
- new users
- guest to member conversion
- total scans
- scan success rate
- cart save rate
- ad impressions
- ad clicks
- CTR

Trends:
- daily active trend
- scan volume trend
- conversion trend
- monetization trend

### 2. Users
Primary audience: CMO, ops, support

Views:
- user list
- guest / member segmentation
- new users
- last seen
- scans per user
- carts per user

Actions:
- inspect user profile
- inspect session history
- eventually suspend/flag user

### 3. Scan Ops
Primary audience: CTO, ops

Views:
- recent scan jobs
- failed jobs
- average processing time
- queue size
- failure code distribution
- correction rate

Actions:
- inspect a job
- see input/output references
- reprocess later (future)

### 4. Carts / Behavior
Primary audience: CMO, product

Views:
- saved carts count
- avg items per cart
- avg cart value
- top save times / usage patterns
- add-to-cart funnel

### 5. Ads / Monetization
Primary audience: CFO, CMO

Views:
- slot list
- impressions by slot
- clicks by slot
- CTR by slot
- top performing placements

Actions:
- enable/disable slot
- adjust slot config (future)

### 6. Config / Flags
Primary audience: CTO, product

Views:
- remote scan on/off
- ads enabled
- experiment flags
- API health references

## Frontend principles (CDO involved)

### Information design
- default landing should answer “what happened today?” in 5 seconds
- avoid crowded enterprise UI feel
- prioritize scan, user, monetization, and growth metrics in clear blocks
- table-heavy screens should still be visually calm

### Visual direction
- clean dashboard, not dark cyber/ops styling
- white/light base with strong accent states
- use clear metric hierarchy
- allow red only for alerts or important status, not everywhere
- charts should be minimal and easy to scan quickly

### UX rules
- overview first, drill-down second
- every metric should have a definition
- every table should support sorting/filtering
- no modal overload; use detail pages/drawers where possible

## Backend admin endpoints (draft)

- `GET /admin/dashboard/summary`
- `GET /admin/dashboard/timeseries`
- `GET /admin/users`
- `GET /admin/users/{userId}`
- `GET /admin/scan-jobs`
- `GET /admin/scan-jobs/{jobId}`
- `GET /admin/ads/slots`
- `PATCH /admin/ads/slots/{slotId}`
- `GET /admin/config`

## Access control

Recommended roles:
- `admin`
- `operator`
- `analyst`

Examples:
- admin: full access
- operator: user/job operational access
- analyst: dashboard + metrics read access only

## Delivery order

1. Dashboard IA finalized
2. DB/event model extended to support KPIs
3. Admin API summary endpoints
4. Next.js admin scaffold
5. Dashboard pages
6. Users / Scan Ops tables
7. Ads / Config pages
