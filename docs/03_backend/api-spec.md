# Cartly API Spec

Last updated: 2026-05-18
Status: canonical
Purpose: API surface contract for app, admin, and runtime configuration flows
Use this doc when: adding routes, integrating clients, or validating endpoint behavior

## 1. 공통 규칙

### base URLs
- public app API: `https://scan-api.seoa-nas.com`
- local backend: `http://127.0.0.1:8011`
- public admin UI: `https://cartly-admin.seoa-nas.com`

### 응답 envelope
성공:
```json
{"ok": true, "data": {}}
```

실패:
```json
{"ok": false, "error": {"code": "...", "message": "..."}}
```

### 인증
- app API: bearer token
- admin API: admin web session + backend `ADMIN_TOKEN` 보호 레이어

## 2. App API (`/v1/*`)

### auth
- `POST /v1/auth/guest`
- `POST /v1/auth/login`
- `POST /v1/auth/email/request-signup-code`
- `POST /v1/auth/email/verify-signup-code`
- `POST /v1/auth/email/register`
- `POST /v1/auth/password/login`
- `POST /v1/auth/password/request-reset-code`
- `POST /v1/auth/password/reset`
- `POST /v1/auth/logout`
- `GET /v1/auth/me`
- `PATCH /v1/auth/me`
- `DELETE /v1/auth/me`

역할:
- guest/member 세션 발급
- 이메일 기반 회원가입/로그인/비밀번호 재설정
- display name 수정
- account deletion

### scan
- `POST /v1/scan/jobs`
- `GET /v1/scan/jobs/{job_id}`
- `GET /v1/scan/jobs/{job_id}/result`
- `POST /v1/scan/jobs/{job_id}/feedback`
- `POST /v1/scan/jobs/{job_id}/failures`

역할:
- 상품/가격표 스캔 업로드
- job polling
- result fetch
- 사용자 피드백/실패 로그 저장

### carts
- `GET /v1/carts`
- `POST /v1/carts`
- `GET /v1/carts/{cart_id}`
- `PATCH /v1/carts/{cart_id}`
- `POST /v1/carts/{cart_id}/retention/extend`
- `DELETE /v1/carts/{cart_id}`

역할:
- saved cart CRUD
- retention extension
- receipt apply 이후의 cart replacement 흐름 포함

### receipts
- `POST /v1/receipts`
- `GET /v1/receipts/{receipt_id}`
- `GET /v1/receipts/{receipt_id}/result`

역할:
- 영수증 업로드 및 분석 시작
- 영수증 상태 조회
- 영수증 결과 조회
- receipt apply용 분석 결과 제공

관련 라우터는 `receipt_service`와 saved cart 흐름에 연결된다.

### households
- `GET /v1/households/me`
- `POST /v1/households/invite-code`
- `POST /v1/households/join`
- `POST /v1/households/leave`
- `GET /v1/households/current-cart`
- `POST /v1/households/current-cart/items`
- `PATCH /v1/households/current-cart/items/{item_id}`
- `DELETE /v1/households/current-cart/items/{item_id}`
- `DELETE /v1/households/current-cart`

역할:
- household 상태 관리
- shared current cart read/write

### app config / runtime
- `GET /v1/app-config`

핵심 payload domain:
- `features`
- `branding`
- `copy`
- `ads`
- 추가 runtime blocks: `push`, `explore`, `runtime`

### app push
- `GET /v1/push/status`
- `POST /v1/push/devices`

역할:
- push readiness 확인
- 앱 디바이스 등록 / 토큰 상태 보고

### ads / events
- `POST /v1/events`
- `POST /v1/ads/impressions`
- `POST /v1/ads/impressions/{id}/click`

역할:
- 제품 사용 이벤트
- 광고/프로모션 노출/클릭 측정

## 3. Admin API (`/admin/*`)

### auth/session
- `POST /admin/login`
- `GET /admin/session`
- `POST /admin/logout`

### dashboard
- summary / refresh / period summary / snapshots 계열

### users
- `GET /admin/users`
- `GET /admin/users/legacy-guests`
- `POST /admin/users/{user_id}/archive-legacy`
- `POST /admin/users/{user_id}/merge-legacy`
- `GET /admin/users/{user_id}/carts`
- `POST /admin/users/{user_id}/household/disconnect`
- `POST /admin/users/{user_id}/household/disband`

### scan ops
- recent jobs / failures / retry / quarantine 계열

### carts
- list / export CSV / export XLSX

### push
- `GET /admin/push/status`
- `GET /admin/push/devices`
- `GET /admin/push/campaigns`
- `POST /admin/push/audience-preview`
- `POST /admin/push/segment-preview`
- `POST /admin/push/broadcast`

### ads
- `GET /admin/ads/slots`
- `PUT /admin/ads/slots/{slot_key}`
- `POST /admin/ads/campaigns`
- `PUT /admin/ads/campaigns/{campaign_id}`
- `POST /admin/ads/campaigns/{campaign_id}/cancel`
- `DELETE /admin/ads/campaigns/{campaign_id}`
- `GET /admin/ads/performance/summary`
- `GET /admin/ads/slots/{slot_key}/workspace`
- `GET /admin/ads/campaigns`
- `GET /admin/ads/campaigns/export.xlsx`
- `GET /admin/ads/campaigns/{campaign_id}/export.xlsx`
- `POST /admin/ads/assets`

### content / branding / config
- `GET/PUT /admin/content`
- `GET/PUT /admin/branding`
- branding asset upload endpoints
- `GET /admin/config`

## 4. 현재 계약에서 중요한 제품 규칙

### guest mode
- guest auth는 정식 product path다.
- review/demo/support에서 중요하다.

### runtime-driven copy
- 앱 핵심 카피는 `/v1/app-config`로 옮기는 방향이 기본이다.

### household
- shared current cart는 member-only endpoint다.
- guest/local-only 흐름과 명확히 분리한다.

### ads targeting
- audience는 `all/member/guest`
- region axis는 `all/city/district/neighborhood`
- 같은 slot 안에서 targeting bucket별로 specificity-first selection

## 5. 자주 보는 에러 성격
- `UNAUTHORIZED`
- `HOUSEHOLD_MEMBER_ONLY`
- `HOUSEHOLD_NOT_FOUND`
- `CURRENT_CART_ITEM_NOT_FOUND`
- `ITEM_NAME_REQUIRED`
- `IMAGE_NOT_FOUND`
- `OPENCLAW_*`
- `WORKER_FAILED`
- `APP_PUBLIC_ROUTE_NOT_FOUND`

## 6. 운영 체크포인트
- public app proxy가 필요한 `/v1/*` route를 실제로 allowlist했는지
- `/v1/app-config`가 최신 branding/copy를 내려주는지
- admin 수정 후 live served API/UI가 새 코드인지
- Python 3.9 호환성 문제가 router/schema에 없는지

## Related notes
- [[03_backend/backend-architecture]]
- [[03_backend/database-schema]]
- [[02_product/family-cart-system]]
- [[04_admin/admin-system]]
