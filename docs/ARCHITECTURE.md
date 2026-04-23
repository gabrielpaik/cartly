# Cartly 아키텍처 문서

> 최종 업데이트: 2026-04-17

---

## 1. 전체 구조 개요

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           사용자 레이어                                    │
│                                                                         │
│   ┌──────────────────────┐          ┌──────────────────────────────┐    │
│   │   Flutter 앱 (iOS)    │          │   Admin Web (Next.js)         │    │
│   │   v1.0.3+17           │          │   운영/모니터링 대시보드         │    │
│   └──────────┬───────────┘          └──────────────┬───────────────┘    │
└──────────────┼────────────────────────────────────┼────────────────────┘
               │ HTTPS (Bearer Token)                │ HTTPS (httpOnly Cookie)
               │ /v1/*                               │ /admin/* + /v1/proxy
               ▼                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      FastAPI 백엔드 (Python 3.x)                         │
│                      Cartly API  ·  port 8011                           │
│                                                                         │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │  Routers                                                         │  │
│   │  /v1/auth   /v1/scan   /v1/carts   /v1/events                   │  │
│   │  /v1/ads    /v1/app-config         /v1/receipts                  │  │
│   │  /admin  ──► (session/dashboard/users/scan-ops/                 │  │
│   │               carts/ads/content/config)                          │  │
│   └──────────────────────────┬───────────────────────────────────────┘  │
│                               │                                          │
│   ┌───────────────────────────▼──────────────────────────────────────┐  │
│   │  Services                                                        │  │
│   │  auth_service · worker_service · scan_service · cart_service    │  │
│   │  admin_service · admin_snapshot_scheduler · openclaw_scan_runner │  │
│   └──────────┬──────────────────────────────────────────────────────┘  │
│              │                                                           │
└──────────────┼───────────────────────────────────────────────────────┘
               │
      ┌────────┼──────────────────────────────────┐
      ▼        ▼                                   ▼
┌──────────┐  ┌────────────────────────────────────────┐
│PostgreSQL│  │           NAS  /Volumes/AI/WIMC/        │
│  DB      │  │                                        │
│  16개    │  │  input/   ← 원본 이미지 업로드            │
│  테이블   │  │  output/  ← 분석 결과 JSON              │
└──────────┘  │  archive/ ← 완료된 이미지 보관           │
              │  failed/  ← 실패 케이스 디버그 파일      │
              └────────────────┬───────────────────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │  OpenClaw CLI         │
                    │  (Claude 기반 AI)     │
                    │  - 가격표 스캔         │
                    │  - 영수증 스캔         │
                    └──────────────────────┘
```

---

## 2. Flutter 앱 레이어

### 2-1. 부트스트랩 순서

```
main() ──► initializeWimcApp()
            ├── availableCameras()        ← 카메라 권한 + 목록
            ├── AuthStore.instance.load() ← 저장된 세션 복원 + 서버 refresh
            ├── CartStore.instance.load() ← 로컬 캐시 + 원격 동기화
            └── AdMobService.initialize() ← AdMob SDK 초기화
                    │
                    ▼
            WimcApp(cameras)
                    │
                    ▼
            SplashScreen (1200ms)
                    │
                    ▼
            HomePage (탭 기반 메인 화면)
```

### 2-2. 상태 관리 구조

```
AppConfigStore (singleton)
  └── ValueNotifier<AppBranding>   branding   ← 로고, 서브타이틀
  └── ValueNotifier<AppRuntimeCopy> copy      ← UI 텍스트
  └── ValueNotifier<List<AppAdSlot>> adSlots  ← 광고 슬롯 설정
      * 앱 foregrounded 될 때마다 refresh()

AuthStore (singleton)
  └── ValueNotifier<UserSession?> session
      * SharedPreferences 'user_session_v1'에 persist
      * 만료 체크 → 서버 refresh → UNAUTHORIZED면 자동 로그아웃

CartStore (singleton)
  └── ValueNotifier<List<SavedCart>> carts
      * SharedPreferences 'saved_carts_v1' + 'saved_carts_owner_v1'
      * 로그인 상태: 원격 우선, 실패시 로컬 캐시 fallback
      * 비로그인 상태: 로컬만 사용
      * 로그인 전환 시 로컬 카트 → 원격 자동 이관
```

### 2-3. 화면 구조

```
HomePage
  ├── HomeTabView
  │     ├── [홈 탭]
  │     │     ├── CurrentCartSection    ← 현재 카트 (미저장)
  │     │     ├── ItemAddSection        ← 스캔 버튼 + 결과 추가
  │     │     └── RecentScanCard        ← 최근 스캔 이력
  │     │
  │     └── [Saved 탭]
  │           ├── SavedTabHeader
  │           ├── SavedTabCartList      ← 저장된 카트 목록
  │           └── SavedTabEmptyState
  │
  ├── CartDetailPage                    ← 저장 카트 상세 (수정/삭제)
  ├── MyPage                            ← 계정 + 설정
  └── LoginPage                         ← 이메일/소셜/게스트 로그인
```

### 2-4. 스캔 플로우 (앱 측)

```
카메라 촬영
    │
    ▼
RemoteScanRepository.submitImage(imagePath)
    ├── POST /v1/scan/jobs  (multipart/form-data)
    └── 응답: { job.id, job.status: 'queued' }
            │
            ▼
        polling loop (1초 간격)
        GET /v1/scan/jobs/{id}
            │
            ├── status: 'processing' ──► 계속 polling
            │
            └── status: 'done'
                    │
                    ▼
                GET /v1/scan/jobs/{id}/result
                    └── RecognizedItemCandidate (name, price, sku, confidence)
                            │
                            ▼
                        사용자 검토 + 수정
                            │
                            ▼
                        POST /v1/scan/jobs/{id}/feedback
                        (accepted: bool, corrected: Item?)
```

### 2-5. 의존 패키지

| 패키지 | 버전 | 용도 |
|--------|------|------|
| camera | ^0.11.3 | 카메라 촬영 |
| permission_handler | ^12.0.1 | 카메라 권한 |
| shared_preferences | ^2.2.3 | 로컬 상태 persist |
| intl | ^0.19.0 | 날짜/숫자 포맷 |
| url_launcher | ^6.3.1 | 외부 링크 |
| google_mobile_ads | ^5.1.0 | AdMob 광고 |
| cupertino_icons | ^1.0.8 | iOS 아이콘 |

---

## 3. Backend 레이어 (FastAPI)

### 3-1. API 엔드포인트 전체 맵

```
GET  /health                              ← 스토리지 + 서버 상태 확인

──── 사용자 API (/v1/*) ─────────────────────────────────────────────────

POST /v1/auth/guest                       ← 게스트 세션 생성 (guest_key 기반)
POST /v1/auth/email/signup                ← 이메일 회원가입
POST /v1/auth/email/login                 ← 이메일 로그인
POST /v1/auth/email/verify                ← 이메일 인증 코드 확인
POST /v1/auth/provider                    ← 소셜 로그인 (Google/Kakao)
GET  /v1/auth/session                     ← 세션 갱신
POST /v1/auth/logout                      ← 로그아웃

POST /v1/scan/jobs                        ← 스캔 작업 생성 (이미지 업로드)
GET  /v1/scan/jobs/{id}                   ← 작업 상태 조회
GET  /v1/scan/jobs/{id}/result            ← 분석 결과 조회
POST /v1/scan/jobs/{id}/feedback          ← 결과 수락/거부 + 수정 피드백
POST /v1/scan/jobs/{id}/failures          ← 앱 측 실패 로그 제출

POST /v1/receipts                         ← 영수증 업로드 + 분석 시작
GET  /v1/receipts/{id}                    ← 영수증 상태/메타 조회
GET  /v1/receipts/{id}/result             ← 영수증 요약 + 상세 + 총액 비교 결과

GET  /v1/carts                            ← 카트 목록
POST /v1/carts                            ← 카트 저장
GET  /v1/carts/{id}                       ← 카트 상세
PUT  /v1/carts/{id}                       ← 카트 수정
DELETE /v1/carts/{id}                     ← 카트 삭제 (soft: status='deleted')
POST /v1/carts/{id}/extend                ← 카트 보관 기간 연장

POST /v1/events                           ← 앱 이벤트 트래킹

POST /v1/ads/impressions                  ← 광고 노출 기록
POST /v1/ads/impressions/{id}/click       ← 광고 클릭 기록

GET  /v1/app-config                       ← 브랜딩 + 광고슬롯 + UI텍스트

──── 어드민 API (/admin/*) ──────────────────────────────────────────────

POST /admin/login                         ← 관리자 로그인 (root_token)
GET  /admin/session                       ← 세션 확인
POST /admin/logout                        ← 관리자 로그아웃

GET  /admin/dashboard/summary             ← DAU/WAU/MAU + 스캔/카트 통계
POST /admin/dashboard/summary/refresh     ← 스냅샷 강제 갱신
GET  /admin/dashboard/period-summary      ← 주/월/분기/연 집계
GET  /admin/dashboard/snapshots           ← 과거 스냅샷 목록

GET  /admin/users                         ← 사용자 목록
GET  /admin/users/legacy-guests           ← guest_key 없는 레거시 게스트
POST /admin/users/{id}/merge-legacy       ← 레거시 게스트 → 멤버 수동 병합
POST /admin/users/{id}/archive-legacy     ← 레거시 게스트 보관 처리
GET  /admin/users/{id}/carts              ← 사용자별 카트 상세

GET  /admin/scan-jobs                     ← 스캔 작업 목록 + 필터
POST /admin/scan-jobs/{id}/retry          ← 실패 작업 재시도
POST /admin/scan-jobs/{id}/quarantine     ← 문제 작업 격리

GET  /admin/carts                         ← 전체 카트 목록
GET  /admin/carts/export.csv              ← CSV 내보내기
GET  /admin/carts/export.xlsx             ← Excel 내보내기

GET  /admin/ads/slots                     ← 광고 슬롯 목록
PUT  /admin/ads/slots/{key}               ← 슬롯 수정 (활성화/비활성화)
GET  /admin/ads/campaigns                 ← 광고 캠페인 목록
GET  /admin/ads/campaigns/export.xlsx     ← 캠페인 Excel 내보내기
POST /admin/ads/assets                    ← 광고 이미지 업로드

GET  /admin/branding                      ← 브랜딩 설정 조회
PUT  /admin/branding                      ← 브랜딩 설정 변경
POST /admin/branding/logo                 ← 로고 이미지 업로드
POST /admin/branding/splash               ← 스플래시 이미지 업로드
POST /admin/branding/login-hero           ← 로그인 히어로 이미지 업로드
GET  /admin/ui-copy                       ← UI 텍스트 조회
PUT  /admin/ui-copy                       ← UI 텍스트 수정
GET  /admin/content                       ← 콘텐츠 통합 조회
PUT  /admin/content                       ← 콘텐츠 통합 수정

GET  /admin/config                        ← 런타임 플래그 (remote_scan, ads_enabled 등)

──── Static ──────────────────────────────────────────────────────────────

/assets/branding/*                        ← 브랜딩 에셋 파일 서빙
/assets/ads/*                             ← 광고 이미지 파일 서빙
```

### 3-2. 스캔 파이프라인 (서버 측)

```
POST /v1/scan/jobs
    │
    ├── validate_image_bytes()    ← Pillow로 이미지 유효성 검증
    ├── create_scan_job()         ← DB에 ScanJob(status='queued') 생성
    │   └── 이미지를 NAS input/{date}/ 에 저장
    └── 응답: job.id, status='queued'

              ↓ (백그라운드 워커 폴링)

worker_service.process_next_job()
    │
    ├── ScanJob(status='queued') 조회
    ├── status → 'processing'
    │
    ├── _run_openclaw(job)
    │     ├── 경로 traversal 방어 (realpath + storage_root 비교)
    │     ├── OPENCLAW_SCAN_COMMAND.format(job_id, image_path) 실행
    │     ├── stdout JSON 파싱 → OpenClawScanResult
    │     └── 실패 시 ScanProcessingError
    │
    ├── [성공]
    │     ├── output/{date}/{job_id}.json 저장
    │     ├── 이미지 → archive/{date}/ 복사
    │     └── ScanJob(status='done')
    │
    └── [실패]
          ├── failed/{date}/{job_id}.json 저장
          ├── ScanJob(status='failed', error_code, error_message)
          └── log_scan_failure() → ScanFailureLog 기록

GET /v1/scan/jobs/{id}/result
    ├── job.status == 'done' 확인
    └── output/ 디렉토리에서 {job_id}.json 읽어서 응답
```

### 3-3. OpenClaw 통합

```
설정값 (환경변수)
  OPENCLAW_SCAN_COMMAND             ← 가격표 스캔 CLI 명령어 템플릿
  OPENCLAW_SCAN_TIMEOUT_SECONDS     ← 타임아웃 (기본 90초)
  OPENCLAW_RECEIPT_SCAN_COMMAND     ← 영수증 스캔 CLI 명령어 템플릿
  OPENCLAW_RECEIPT_SCAN_TIMEOUT_SECONDS ← 타임아웃 (기본 120초)

가격표 스캔 실행
  run_openclaw_scan(job_id, image_path)
    → OPENCLAW_SCAN_COMMAND.format(job_id=..., image_path=...)
    → subprocess 실행 → stdout JSON 파싱
    → OpenClawScanResult(name, price, sku, confidence, source, raw_text)

영수증 스캔 실행
  run_openclaw_receipt(receipt_id, image_path)
    → OPENCLAW_RECEIPT_ANALYSIS_COMMAND 또는 receipt 전용 fallback command 실행
    → OpenClawReceiptResult(
        merchant_name, purchased_at, currency,
        subtotal, tax, total_amount, total_discount_amount,
        line_items: [OpenClawReceiptLineItem]
      )

오류 코드
  OPENCLAW_COMMAND_NOT_CONFIGURED   ← 환경변수 미설정
  OPENCLAW_TIMEOUT                  ← 타임아웃 초과
  OPENCLAW_COMMAND_EXEC_FAILED      ← subprocess 실행 자체 실패
  OPENCLAW_COMMAND_FAILED           ← returncode != 0
  OPENCLAW_EMPTY_OUTPUT             ← stdout 비어있음
  OPENCLAW_INVALID_JSON             ← JSON 파싱 실패
  OPENCLAW_RESULT_INVALID           ← name/price 필드 누락 또는 잘못된 값
  OPENCLAW_SCAN_FAILED              ← OpenClaw 자체 분석 실패 (ok: false)
```

### 3-4. 인증 구조

```
게스트 인증
  POST /v1/auth/guest  { guest_key: 'stable-device-id' }
    ├── guest_key로 기존 User 조회
    ├── 없으면 새 User(is_guest=True) 생성
    ├── guest_code 할당 (Guest#0001 형식)
    └── Session(TTL 7일) 발급 → Bearer Token 응답

멤버 인증
  POST /v1/auth/email/signup  { email, password }
  POST /v1/auth/email/login   { email, password }
  POST /v1/auth/provider      { provider, token, guest_key? }
    └── guest_key 제공 시: 게스트 데이터(카트 등) → 멤버 계정으로 자동 병합

세션 갱신
  GET /v1/auth/session  Authorization: Bearer {token}
    ├── token_hash SHA256로 Session 조회
    ├── expires_at 만료 체크 → 만료시 삭제 후 401
    ├── last_seen_at 갱신
    └── 새 세션 응답

관리자 인증
  POST /admin/login  { password: root_token }
    └── AdminSession(httpOnly cookie, TTL 12시간) 발급
```

### 3-5. DB 모델 (16개 테이블)

```
사용자/세션
  User              id, display_name, email, auth_provider, is_guest,
                    guest_key, guest_code, status, merged_into_user_id,
                    last_device_platform, last_app_version, last_seen_at
  Session           token_hash, user_id, is_guest, expires_at, last_seen_at
  AdminSession      token_hash, expires_at, last_seen_at
  EmailAuthCode     email, code_hash, expires_at, used_at

스캔
  ScanJob           user_id, status, source_image_path, error_code,
                    error_message, started_at, finished_at
  ScanFeedback      job_id, user_id, accepted, original_json, corrected_json
  ScanFailureLog    job_id, user_id, stage, error_code, error_message, details_json

카트
  Cart              user_id, title, status, total_price_cached,
                    total_count_cached, expires_at, retention_extension_count
  CartItem          cart_id, name, price, quantity, source, scan_job_id

광고
  AdSlot            slot_key, placement_type, status, config_json
  AdCampaign        slot_id, name, type, asset_url, link_url, status
  AdImpression      slot_id, user_id, campaign_id, session_id, platform
  AdClick           impression_id, user_id, action_type

앱 설정/이벤트
  AppSetting        key, value (브랜딩, UI텍스트 KV 저장소)
  AppEvent          user_id, event_name, properties_json, session_id
  AdminDashboardSnapshot  snapshot_date, dau/wau/mau/active_users/...
```

### 3-6. 환경 설정 (settings.py)

```
DATABASE_URL              postgresql+psycopg://localhost:5432/wimc
STORAGE_ROOT              /Volumes/AI/WIMC
RUNTIME_ASSETS_ROOT       ~/Library/Application Support/WIMC/assets
BEARER_SECRET             세션 토큰 서명 키
ADMIN_TOKEN               관리자 root_token
API_BASE_URL              http://127.0.0.1:8011
REMOTE_SCAN_ENABLED       true/false
ADS_ENABLED               true/false
OPENCLAW_SCAN_COMMAND     가격표 스캔 CLI 템플릿
OPENCLAW_SCAN_TIMEOUT_SECONDS         90
OPENCLAW_RECEIPT_SCAN_COMMAND         영수증 스캔 CLI 템플릿
OPENCLAW_RECEIPT_SCAN_TIMEOUT_SECONDS 120
SMTP_*                    이메일 인증 발송용
```

---

## 4. Admin Web 레이어 (Next.js)

### 4-1. 구조

```
admin-web/
  app/
    layout.tsx              ← AdminChrome 래퍼 (네비게이션 + 로그인 체크)
    page.tsx                ← /overview 로 redirect
    login/page.tsx          ← 관리자 로그인 화면
    overview/page.tsx       ← DAU/WAU/MAU + 스캔/카트 통계
    users/page.tsx          ← 사용자 목록
    users/[id]/page.tsx     ← 사용자 상세 + 카트 이력 + 레거시 병합
    scan-ops/page.tsx       ← 스캔 작업 모니터링
    carts/page.tsx          ← 저장 카트 현황
    ads/page.tsx            ← 광고 슬롯 관리
    content/page.tsx        ← 브랜딩 + UI텍스트 편집
    config/page.tsx         ← 런타임 플래그

    api/
      admin-auth/login/     ← POST: root_token → AdminSession cookie 발급
      admin-auth/logout/    ← POST: cookie 삭제
      cartly-admin/[...]/   ← /admin/* 백엔드 프록시 (cookie 인증 relay)
    v1/
      auth/[...]/           ← /v1/auth/* 프록시
      scan/[...]/           ← /v1/scan/* 프록시
      carts/[...]/          ← /v1/carts/* 프록시
      events/[...]/         ← /v1/events/* 프록시
      ads/[...]/            ← /v1/ads/* 프록시
      app-config/           ← /v1/app-config 프록시
    assets/
      branding/[...]/       ← 브랜딩 에셋 프록시
      ads/[...]/            ← 광고 에셋 프록시

  middleware.ts             ← 비로그인 시 /login 리다이렉트
  components/
    AdminChrome             ← 레이아웃 셸 (사이드바 + AdminCopyProvider)
    AdminCopyProvider       ← 어드민 UI 텍스트 Context
    LoginScreen             ← 로그인 폼
    LogoutButton            ← 세션 종료
    PageHeader              ← 페이지 제목 + Live/Fallback 배지
    StatCard                ← KPI 숫자 카드
    NavLink                 ← 사이드바 링크

  lib/
    api.ts                  ← fetchJson/putJson/postJson (ApiError + 401 재throw)
    fetchJsonSafe()         ← 네트워크 오류 시 fallback 반환 (401/403 제외)
    useAdminData()          ← 클라이언트 데이터 훅 (KST 자정 캐시 갱신)
    format.ts               ← formatDate / formatNumber / formatPercent / statusTone
    mock.ts                 ← 개발/fallback용 목 데이터
    serverConfig.ts         ← 서버 사이드 설정
    adminCopyDefaults.ts    ← 어드민 UI 텍스트 기본값
    appPublicProxy.ts       ← 앱 공개 API 프록시 헬퍼
```

### 4-2. 인증 흐름

```
브라우저 접근
    │
    ▼
middleware.ts
    ├── /admin/session 쿠키 확인
    ├── 없으면 → /login 리다이렉트
    └── 있으면 → 페이지 접근 허용

로그인
  LoginScreen → POST /api/admin-auth/login { password }
                  → 백엔드 POST /admin/login
                  → AdminSession 생성
                  → Set-Cookie: admin_session (httpOnly, 12시간)

API 요청
  fetchJson('/admin/xxx')
    → GET /api/cartly-admin/xxx  (같은 origin)
    → Next.js 프록시: cookie relay → 백엔드 /admin/xxx
    → 401/403 받으면 ApiError throw → 로그인 화면으로
```

### 4-3. 데이터 전략

```
서버 컴포넌트 (RSC)
  fetchJsonSafe(url, fallback)
    ├── 성공: { data: 실데이터, usingFallback: false }
    └── 실패: { data: fallback, usingFallback: true }
  → PageHeader badge로 Live/Fallback 표시

클라이언트 컴포넌트
  useAdminData(url, fallback)
    ├── localStorage에 KST 자정 기준 일별 캐시
    ├── 캐시 유효: 캐시 데이터 즉시 표시 후 백그라운드 갱신
    └── reload() 수동 갱신 지원
```

---

## 5. 데이터 흐름 전체 시퀀스

### 5-1. 가격표 스캔 (핵심 플로우)

```
[앱] 카메라 촬영 → imagePath
    │
    ▼
[앱] POST /v1/scan/jobs  multipart/form-data (image)
    │
    ▼
[백엔드] scan_service.create_scan_job()
    ├── Pillow 이미지 유효성 검증
    ├── NAS: input/{date}/{job_id}.jpg 저장
    └── DB: ScanJob(status='queued') 생성
    │
    ▼ 응답: { job.id, status: 'queued' }
    │
[앱] 1초마다 GET /v1/scan/jobs/{id} polling
    │
    ▼
[백엔드 워커] process_next_job()  ← 별도 프로세스/스레드
    ├── status → 'processing'
    ├── OpenClaw CLI 실행 (job_id, image_path)
    │     └── Claude AI 분석: 상품명 + 가격 추출
    ├── output/{date}/{job_id}.json 저장
    ├── image → archive/ 복사
    └── status → 'done'
    │
[앱] status == 'done'
    │
    ▼
[앱] GET /v1/scan/jobs/{id}/result
    │
    ▼
[백엔드] output/ 디렉토리에서 JSON 읽어 응답
  { result: { name, price, sku, confidence, source, rawText } }
    │
    ▼
[앱] RecognizedItemCandidate 표시
    ├── 사용자 수락 → POST /feedback { accepted: true }
    └── 수정 후 수락 → POST /feedback { accepted: true, corrected: {...} }
```

### 5-2. 카트 저장 플로우

```
[앱] CartStore.saveNewCart(items, title?)
    │
    ├── [로그인 상태]
    │     ├── RemoteCartRepository.createCart(token, cart)
    │     │     └── POST /v1/carts { title, items: [{name, price, quantity, scanResultId}] }
    │     ├── 성공: 서버 응답 카트 로컬 캐시 업데이트
    │     └── 실패: 로컬에만 저장 (추후 동기화)
    │
    └── [비로그인 상태]
          └── SharedPreferences에만 저장

[앱] 로그인 시
    CartStore.load()
        ├── 로컬 카트 있고 원격 비어있으면: 로컬 → 원격 이관 (createCart 일괄 호출)
        └── 이후 원격 목록으로 로컬 캐시 교체
```

---

## 6. 인프라 구성

```
┌─────────────────────────────────────────────────────────┐
│  Mac mini (NAS 서버, seoa-nas.local)                    │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │  FastAPI  (port 8011)                             │  │
│  │  uvicorn --reload                                 │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │  PostgreSQL  (wimc DB)                            │  │
│  │  16개 테이블                                       │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │  NAS  /Volumes/AI/WIMC/                           │  │
│  │    input/   processing/   output/                 │  │
│  │    archive/  failed/                              │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │  OpenClaw (Claude 기반 AI CLI)                    │  │
│  │  가격표 스캔 / 영수증 스캔                          │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Admin Web (Next.js, 별도 port)                   │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
└─────────────────────────────────────────────────────────┘
          │                          │
          │ Cloudflare Tunnel         │ Cloudflare Tunnel
          ▼                          ▼
   앱 API 공개 도메인           Admin 전용 도메인 (VPN/IP 제한)
```

---

## 7. 현재 상태 체크리스트

| 영역 | 항목 | 상태 |
|------|------|------|
| **스캔** | OpenClaw 가격표 스캔 | ✅ 완료 |
| **스캔** | OpenClaw 영수증 스캔 | ✅ 완료 (receipts 라우터) |
| **스캔** | 스캔 피드백 수집 | ✅ 완료 |
| **스캔** | 실패 로그 기록 | ✅ 완료 |
| **카트** | 저장/조회/수정/삭제 | ✅ 완료 |
| **카트** | 로컬↔원격 동기화 | ✅ 완료 |
| **카트** | 게스트→멤버 전환 시 이관 | ✅ 완료 |
| **인증** | 게스트 세션 (guest_key) | ✅ 완료 |
| **인증** | 이메일 인증 | ✅ 완료 |
| **인증** | 소셜 로그인 | ✅ 완료 |
| **광고** | AdMob 배너 | ✅ 완료 |
| **광고** | 광고 슬롯 impression/click | ✅ 완료 |
| **어드민** | 대시보드 통계 | ✅ 완료 |
| **어드민** | 사용자 관리 + 레거시 병합 | ✅ 완료 |
| **어드민** | 스캔 작업 재시도/격리 | ✅ 완료 |
| **어드민** | 브랜딩/UI텍스트 편집 | ✅ 완료 |
| **어드민** | 카트 Excel 내보내기 | ✅ 완료 |
| **네이밍** | wimc → cartly 통일 | ⚠️ 일부 미완 (파일명, pubspec) |
| **워크트리** | cranky-mclean → main 머지 | ⚠️ 대기 중 |
| **테스트** | 자동화 테스트 | ❌ 없음 |
| **배포** | CI/CD 파이프라인 | ❌ 수동 배포 |
