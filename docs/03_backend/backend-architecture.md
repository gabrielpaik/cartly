# Cartly Backend Architecture

Last updated: 2026-05-18
Status: canonical
Purpose: backend system contract covering runtime topology, responsibilities, and architectural rules
Use this doc when: changing backend boundaries, service responsibilities, or runtime assumptions

## 1. 역할
Cartly backend는 단순 API 서버가 아니라 아래 4가지를 동시에 맡는다.
1. 앱의 source of truth
2. OCR/영수증 비동기 처리 오케스트레이터
3. admin/operator control plane backend
4. runtime config / branding / content delivery layer

## 2. 런타임 토폴로지
- app/public entry: `https://scan-api.seoa-nas.com` → app public proxy → backend `127.0.0.1:8011`
- admin entry: `https://cartly-admin.seoa-nas.com` → admin web `127.0.0.1:3000` → backend `127.0.0.1:8011`
- backend itself stays private on localhost
- NAS storage root: `/Volumes/AI/Cartly`

## 3. 핵심 레이어

### Router layer
주요 라우터 묶음:
- `/v1/auth`
- `/v1/scan`
- `/v1/receipts`
- `/v1/carts`
- `/v1/households`
- `/v1/events`
- `/v1/ads`
- `/v1/app-config`
- `/admin/*`

### Service layer
주요 서비스 축:
- `auth_service`
- `cart_service`
- `receipt_service`
- `worker_service`
- `household_service`
- `household_current_cart_service`
- `app_config_service`
- `branding_service`
- `app_copy_service`
- `push_service`
- `user_region_service`
- `ad_slot_service`
- `admin_user_service`

### Persistence layer
- PostgreSQL/SQLite 호환 SQLAlchemy 모델 기반
- DB가 상태의 source of truth
- NAS는 파일/분석 아티팩트/런타임 인프라

## 4. 앱 대상 핵심 책임

### 인증
- guest session 발급
- 이메일 코드 기반 가입
- 비밀번호 로그인
- 비밀번호 재설정
- `GET /me`, `PATCH /me`, `DELETE /me`

### 장보기 상태
- saved cart CRUD
- receipt upload / analysis / apply 기반 흐름
- household 상태 관리
- shared current cart 상태 제공

### runtime delivery
- `/v1/app-config`에서 branding, copy, ads, feature flags, push/explore/runtime settings 제공

### app push readiness
- 앱 디바이스 등록
- push token / invalidation 상태 관리
- operator push delivery와 연결되는 app-side 준비상태 제공

## 5. admin 대상 핵심 책임
- 사용자/legacy guest/household 운영
- push status/device/campaign/broadcast
- ads slot/workspace/campaign/performance
- content/branding/runtime settings
- 운영 요약과 health visibility

## 6. current architecture의 중요한 결정

### 1) DB 우선
- 사용자 상태, 세션, 카트, 영수증, household, push, ads는 DB가 기준이다.
- NAS는 스캔 원본/결과/로그/아카이브 저장소다.

### 2) OCR은 비동기
- 앱 요청은 job 생성
- worker가 큐를 비운다
- 결과 JSON 아티팩트와 DB 상태가 함께 남는다.

### 3) runtime-driven app
- 앱 하드코딩 카피/브랜딩을 줄이고 `/v1/app-config`로 제어한다.

### 4) operator-console support
- backend가 admin의 compact operator workflows를 직접 뒷받침해야 한다.
- 단순 CRUD보다 preview/workspace/segment/summary API가 중요하다.

## 7. 현재 실제 엔드포인트 축

### auth
- guest 발급
- 로그인/회원가입/비밀번호 재설정
- account patch/delete

### carts
- 목록/상세/저장/수정/삭제
- retention extend

### receipts
- 업로드
- 상태 조회
- 결과 조회

### households
- 상태 조회
- invite code 발급
- join/leave
- shared current cart read/write/clear

### app push
- status
- device registration

### admin users
- user list
- legacy guest 정리
- carts drilldown
- household disconnect/disband

### admin push
- status
- devices
- campaigns
- audience/segment preview
- broadcast

### admin ads
- slots
- campaigns
- workspace
- performance summary
- asset upload

## 8. Python/runtime 제약
- live backend runtime baseline은 Homebrew Python 3.12 계열이다.
- router/schema/service 추가 시 Python 3.12 runtime + current dependency set 기준으로 검토한다.
- backend/worker launch path는 `backend/.venv` 고정이므로, Python 업그레이드는 스크립트 경로 수정이 아니라 venv 재생성 + runtime refresh로 처리한다.

## 9. 운영상 중요한 backend 규칙
- admin/public 수정 후 served runtime을 재기동/검증한다.
- login-session context를 벗어난 backend는 NAS write가 깨질 수 있다.
- `/health`의 `storageWritable`은 실제 운영 판단에 중요하다.

## 10. 관련 핵심 파일
- `backend/app/db/models.py`
- `backend/app/routers/*.py`
- `backend/app/services/*.py`
- `scripts/refresh-runtime.sh`
- `scripts/Cartly Runtime Refresh.command`

## Related notes
- [[03_backend/database-schema]]
- [[03_backend/api-spec]]
- [[03_backend/ai-ocr-system]]
- [[06_infra/infra-system]]
