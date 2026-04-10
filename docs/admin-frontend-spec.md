# Cartly Admin frontend spec v1

## Purpose

Define the first usable admin web UI for Cartly.

This should be readable enough for daily use by:
- CEO
- CMO
- CFO
- CTO
- operator/support roles later

## Primary navigation

Top-level nav:
- Overview
- Users
- Scan Ops
- Carts
- Ads
- Config

## Page 1: Overview

### Top KPI row
- DAU
- WAU
- MAU
- Active Users
- New Users
- Guest → Member Conversion
- Total Scans
- Scan Success Rate
- Cart Save Rate
- Ad CTR

### Charts section
- 14-day DAU trend
- scans by day
- save rate by day
- impressions/clicks by day

### Alert section
- failed jobs spike
- OCR success drop
- ad CTR drop

## Page 2: Users

### Table columns
- user id
- display name
- email
- provider
- guest/member
- created at
- last seen at
- scans
- saved carts

### Detail panel
- sessions
- recent events
- recent scans
- recent carts

## Page 3: Scan Ops

### Table columns
- job id
- user
- status
- created at
- processing time
- failure code
- corrected by user?

### Detail panel
- raw status
- source image path/ref
- result summary
- raw OCR text (future)

## Page 4: Ads

### Table columns
- slot key
- placement type
- enabled
- impressions
- clicks
- CTR

## Page 5: Config

### Config cards
- remote scan enabled
- ads enabled
- app version notes
- API health

## CDO design notes

- Keep spacing generous. Admin should feel calm, not noisy.
- Metrics should have strong visual hierarchy: large number, small label, subtle delta.
- Tables should be legible first; decorative styling second.
- Use consistent status colors:
  - green: healthy / done
  - amber: warning / queued / degraded
  - red: failed / alert
  - blue: informational
- Prefer cards + tables + side panels over too many modals.

## CMO notes

- Dashboard should surface growth and monetization first, not only technical status.
- Conversion metrics should always be visible on Overview.
- Guest/member mix should be easy to inspect.
- Ad performance should be understandable without exporting data.

## CTO notes

- Build the admin so each page can start with mock JSON and then switch to real `/admin/*` APIs.
- Do not hardcode analytics assumptions in UI components.
- Keep chart components and table components reusable.
