# Cartly DB schema draft v1

## 1. users
Purpose: account identity

Fields:
- id (uuid, pk)
- email (unique, nullable for guest conversion flows)
- display_name
- auth_provider (`local`, `apple`, `google`, `guest`, etc.)
- status (`active`, `disabled`)
- created_at
- updated_at

## 2. sessions
Purpose: signed-in session tracking

Fields:
- id (uuid, pk)
- user_id (fk -> users.id, nullable for guest session if needed)
- device_id (fk -> devices.id, nullable)
- token_hash / session_key
- is_guest
- expires_at
- created_at
- last_seen_at

## 3. devices
Purpose: app install / device identity

Fields:
- id (uuid, pk)
- user_id (fk -> users.id, nullable)
- platform (`ios`, `android`, `macos`, etc.)
- app_version
- os_version
- locale
- created_at
- updated_at

## 4. scan_jobs
Purpose: lifecycle of each scan request

Fields:
- id (uuid, pk)
- user_id (fk -> users.id, nullable)
- session_id (fk -> sessions.id, nullable)
- device_id (fk -> devices.id, nullable)
- source_image_path
- source_image_url (nullable, if exposed via API)
- status (`queued`, `uploading`, `processing`, `done`, `failed`)
- error_code (nullable)
- error_message (nullable)
- started_at (nullable)
- finished_at (nullable)
- created_at
- updated_at

Indexes:
- (user_id, created_at desc)
- (status, created_at)

## 5. scan_results
Purpose: normalized OCR/AI result per job

Fields:
- id (uuid, pk)
- scan_job_id (unique, fk -> scan_jobs.id)
- item_name
- item_price
- item_sku (nullable)
- confidence (nullable)
- source (`nas-ai`, `local-fallback`, `manual`)
- raw_text (nullable)
- raw_payload_json (jsonb, nullable)
- created_at
- updated_at

## 6. carts
Purpose: logical saved carts

Fields:
- id (uuid, pk)
- user_id (fk -> users.id, nullable for guest/local migration)
- title (nullable)
- status (`active`, `archived`, `deleted`)
- total_price_cached (nullable)
- total_count_cached (nullable)
- created_at
- updated_at

Indexes:
- (user_id, updated_at desc)

## 7. cart_items
Purpose: line items in carts

Fields:
- id (uuid, pk)
- cart_id (fk -> carts.id)
- scan_result_id (fk -> scan_results.id, nullable)
- name
- price
- quantity
- source (`scan`, `manual`, `edited`)
- created_at
- updated_at

## 8. app_events
Purpose: generic product analytics / growth events

Fields:
- id (uuid, pk)
- user_id (fk -> users.id, nullable)
- session_id (fk -> sessions.id, nullable)
- device_id (fk -> devices.id, nullable)
- event_name
- screen_name (nullable)
- event_props (jsonb)
- created_at

Recommended event names:
- app_open
- login_started
- login_completed
- scan_started
- scan_uploaded
- scan_succeeded
- scan_failed
- scan_corrected
- item_added_to_cart
- cart_saved
- cart_opened
- cart_deleted
- ad_impression
- ad_click

## 9. ad_slots
Purpose: server-configured ad surfaces

Fields:
- id (uuid, pk)
- slot_key (unique)  // e.g. `home_result_inline_1`
- placement_type (`inline`, `drawer`, `post_save`, etc.)
- status (`active`, `paused`)
- config_json (jsonb)
- created_at
- updated_at

## 10. ad_impressions
Purpose: monetization measurement

Fields:
- id (uuid, pk)
- slot_id (fk -> ad_slots.id)
- user_id (fk -> users.id, nullable)
- session_id (fk -> sessions.id, nullable)
- device_id (fk -> devices.id, nullable)
- campaign_id (nullable)
- creative_id (nullable)
- screen_name (nullable)
- created_at

## 11. ad_clicks
Purpose: monetization measurement

Fields:
- id (uuid, pk)
- impression_id (fk -> ad_impressions.id)
- created_at

## Optional next tables

### 12. feature_flags
- key
- enabled
- config_json
- updated_at

### 13. pricing_rules / subscriptions
Only when premium model is introduced.

## Notes

- PostgreSQL is the recommended source of truth.
- NAS file paths should be referenced from DB rows, but not replace DB lifecycle state.
- `scan_jobs` and `scan_results` are the critical bridge between app UX, AI pipeline, analytics, and monetization.
- `app_events` should exist from early stage so CFO/CMO-level analysis becomes possible later.
