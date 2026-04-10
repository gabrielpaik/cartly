# Cartly commercial architecture v1

## Product stance

Cartly is not just a single-device OCR helper. It should be treated as a multi-user commerce utility product with:
- account/session support
- cloud/NAS-backed scan processing
- cart history
- event tracking
- ad/monetization surfaces
- future personalization and retention loops

## System layers

### 1. Client app (Flutter)
Responsibilities:
- auth entry and session handling
- image capture
- upload scan job request
- polling/result fetch
- correction UX for OCR results
- cart save/edit/view
- ad slot rendering
- event emission

The app should not know NAS file paths directly.

### 2. API backend
Recommended role:
- public app-facing entrypoint
- JWT/session auth
- scan job creation
- scan result fetch
- cart CRUD
- profile/account endpoints
- event ingestion
- ad config delivery
- admin/internal endpoints

Recommended stack:
- FastAPI or NestJS
- Keep this as the source of truth for app state and business logic

### 3. Database
Database is mandatory for commercial operation.
Use PostgreSQL as the primary relational store.

DB responsibilities:
- users and sessions
- scan job lifecycle
- normalized scan results
- carts and cart items
- events / analytics
- ad impressions and clicks
- feature flags / configs if needed

### 4. Worker / AI processing
Responsibilities:
- take queued scan jobs
- read uploaded image references
- run OCR / VLM / parsing pipeline
- normalize output
- write results back to DB and file storage

This should be asynchronous and horizontally scalable later.

### 5. NAS storage + AI runtime
Current physical base:
- `/Volumes/AI`

Recommended app workspace:
- `/Volumes/AI/Cartly`

NAS responsibilities:
- raw image storage
- processed result file retention
- model files
- logs and archives
- worker runtime assets

NAS should be treated as processing/storage infrastructure, not as the app's state authority.

## High-level flow

1. User signs in or continues as guest
2. App captures an image
3. App uploads image to backend
4. Backend creates `scan_job`
5. Worker processes image using NAS-based pipeline
6. Worker stores result
7. App polls job status
8. App fetches result
9. User edits result if needed
10. App saves item into cart
11. App emits events for usage and monetization analytics

## Commercial requirements baked into architecture

### Multi-user
Must support:
- user identity
- guest sessions
- device linkage
- user-specific history
- user-specific carts

### Monetization readiness
Must support:
- slot-based ad config
- impression logging
- click logging
- attribution hooks
- per-surface experimentation later

### Growth / marketing readiness
Must support:
- event collection
- funnel measurement
- retention analysis
- user segmentation
- campaign performance mapping later

## Why file-only orchestration is not enough

A pure file-based NAS workflow is insufficient for commercial scale because it is weak at:
- multi-user state management
- concurrent jobs
- analytics and monetization attribution
- user/session tracking
- operational debugging at product scale

Therefore:
- DB = source of truth for state
- NAS = file/model/runtime infrastructure

## Recommended deployment shape (pragmatic)

### Initial commercial-capable version
- Flutter client
- FastAPI backend
- PostgreSQL
- NAS-backed worker
- simple queue strategy (DB-backed or lightweight Redis queue)

### Later scale-up path
- dedicated job queue (Redis/Celery, BullMQ, etc.)
- object storage abstraction if NAS pathing becomes limiting
- admin dashboard
- analytics warehouse / BI sync

## Cartly NAS folder recommendation

```text
/Volumes/AI/Cartly/
  config/
  input/
  processing/
  output/
  failed/
  archive/
  logs/
  temp/
```

This folder tree is for storage/runtime only. Core product state should still live in PostgreSQL.
