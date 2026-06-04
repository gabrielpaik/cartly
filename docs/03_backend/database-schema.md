# Cartly Database Schema

Last updated: 2026-05-18
Status: canonical
Purpose: canonical schema reference for Cartly product, growth, household, and operator data
Use this doc when: adding tables/fields, reasoning about source of truth, or validating model changes

## 1. 원칙
- DB는 Cartly product state의 source of truth다.
- NAS 경로/파일은 보조 아티팩트다.
- 스캔/영수증/카트/household/push/ads/admin snapshot은 모두 DB 기준으로 설명한다.

## 2. 현재 핵심 테이블 목록

### 계정 / 세션
- `users`
- `sessions`
- `admin_sessions`
- `email_auth_codes`

### 고객 지역 / CRM
- `user_region_events`
- `user_region_profiles`

### 스캔 / 품질
- `scan_jobs`
- `scan_feedback`
- `scan_failure_logs`
- `category_overrides`

### 카트 / 영수증
- `carts`
- `cart_items`
- `receipts`
- `receipt_line_items`

### 가족공유
- `households`
- `household_memberships`
- `household_current_carts`
- `household_current_cart_items`

### 운영 / 성장 / 광고
- `app_events`
- `ad_slots`
- `ad_campaigns`
- `ad_impressions`
- `ad_clicks`
- `push_devices`
- `push_campaigns`
- `app_settings`
- `admin_dashboard_snapshots`

## 3. 도메인별 설명

### users
역할:
- guest/member 공통 사용자 레코드
- display name, auth provider, status 보유
- member profile / deletion / household와 연결

주요 필드 개념:
- `id`
- `email`
- `display_name`
- `auth_provider`
- `is_guest`
- `status`
- `created_at`, `updated_at`

### sessions
역할:
- 로그인/게스트 세션 추적
- 디바이스/유저와 연결
- 토큰 수명 관리

### email_auth_codes
역할:
- 이메일 회원가입/비밀번호 재설정 인증코드 관리

## 4. 고객 지역 CRM

### user_region_events
역할:
- 활동 지역 이벤트 기록
- 고객을 단일 고정 지역으로 보지 않고 활동 히스토리로 본다.

### user_region_profiles
역할:
- 최근 활동지역
- 상위 활동지역
- 활동지역 수
- segmentation / ads targeting / push preview용 집계

## 5. 스캔 / 품질 도메인

### scan_jobs
역할:
- 스캔 요청 lifecycle
- 이미지 경로, 상태, 에러, 시작/종료 시간 추적

대표 status:
- `queued`
- `processing`
- `done`
- `failed`

### scan_feedback
역할:
- 사용자 accepted/corrected feedback 저장
- OCR 품질 회고와 운영 지표에 사용

### scan_failure_logs
역할:
- worker/openclaw/runtime 단계 실패 로그 저장

### category_overrides
역할:
- 사용자가 수정한 상품 카테고리 보정값 저장

## 6. 카트 / 영수증 도메인

### carts
역할:
- 저장 카트 본체
- 작업물과 구매 이력 흐름을 연결하는 중심 엔터티

중요 개념:
- saved cart는 mutable한 작업물
- purchase-complete 판단은 내부 로직/운영용
- customer-facing 대표 날짜는 purchasedAt 우선 규칙 적용

### cart_items
역할:
- 저장 카트 line item
- 가격/수량/원본명/카테고리/할인 메타데이터 보유

### receipts
역할:
- 저장 카트에 연결된 영수증 분석 결과 헤더
- merchant, purchasedAt, totalAmount, subtotal, tax, totalDiscountAmount 보유

### receipt_line_items
역할:
- 영수증 상세 행
- item / subtotal / tax / discount / payment 등 category 구분

## 7. 가족공유 도메인

### households
역할:
- 가족공유 그룹 헤더

### household_memberships
역할:
- owner/member 관계 표현
- invite/join/leave/disband 판단의 기준

### household_current_carts
역할:
- household 단위 공동 현재 카트 draft 헤더
- 누가 마지막으로 수정했는지 추적

### household_current_cart_items
역할:
- 공동 현재 카트 item row
- item-level id 기반 동기화 지원

## 8. 성장 / 광고 / 운영 도메인

### app_events
역할:
- 제품 funnel / usage analytics 기본 이벤트 저장

### ad_slots
역할:
- 런타임 placement slot 정의
- 현재는 campaign row source of truth에서 파생되는 runtime slot view와 함께 본다.

### ad_campaigns
역할:
- 실제 광고/프로모션 캠페인 row
- audience, region, 기간, creative, landing, sortOrder 등을 포함하는 운영 단위

### ad_impressions / ad_clicks
역할:
- 노출/클릭 측정
- slot / campaign / creative / session/user 문맥 연결

### push_devices
역할:
- 설치 디바이스 / push token 상태 / invalidation 관리

### push_campaigns
역할:
- broadcast / segment_json / audience preview 기반 발송 이력

### app_settings
역할:
- runtime flags, branding, content, explore config, public site config 등 key-value setting 저장

### admin_dashboard_snapshots
역할:
- 운영 대시보드 집계 snapshot

## 9. 현재 스키마 설계의 중요한 판단
- household shared current cart는 saved cart를 재활용하지 않고 별도 테이블로 분리한다.
- ad runtime config는 campaign row 중심 운영을 보조하는 형태로 본다.
- user region은 단일 현재 주소가 아니라 활동 이벤트 + profile 집계 구조로 본다.
- receipt는 cart의 보조 첨부가 아니라 실제 구매 정답에 가까운 구조로 본다.

## 10. 앞으로 스키마 변경 시 체크리스트
- guest/member 전환 호환성 유지 여부
- household teardown 시 orphan cleanup 여부
- admin export / KPI 집계 영향 여부
- app-config / runtime derivation 영향 여부
- Python 3.12 local runtime 및 현 운영 DB 마이그레이션 안전성 여부

## Related notes
- [[03_backend/backend-architecture]]
- [[03_backend/realtime-sync-system]]
- [[03_backend/ai-ocr-system]]
