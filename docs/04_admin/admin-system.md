# Cartly Admin System

Last updated: 2026-05-18
Status: canonical
Purpose: admin operator-console contract for IA, page roles, and runtime verification discipline
Use this doc when: changing admin structure, operator workflows, or content/runtime control surfaces

## 1. 역할
Cartly admin은 developer panel이 아니라 **operator console**이다.
주요 역할은 세 가지다.
1. 운영 상황 파악
2. 사용자/스캔/광고/푸시 제어
3. 앱 런타임 콘텐츠와 브랜딩 관리

## 2. 핵심 원칙

### operator-console grammar
- dense header
- compact horizontal filter strip
- table/list first
- selected row workspace / sheet
- runtime preview / live state visibility

### 하지 말아야 할 것
- 긴 페이지형 폼으로 회귀
- anchor jump subnav 남발
- source code만 보고 성공 판정
- stale runtime 상태로 화면 평가

## 3. 정보 구조
현재 durable decision:
- **Operations는 완료된 baseline**
- **Growth가 relayout의 주 대상**

실제 운영 그룹:
- Overview
- Users
- Carts
- Scan Ops
- Push
- Ads
- Content
- Config
- Explore

## 4. 페이지 역할 정의

### Overview
- 오늘 무슨 일이 있었는지 5초 안에 보여주는 landing
- runtime health / operator alerts / quick actions / recent changes 중심

### Users
- passive directory가 아니라 customer DB + segmentation console
- member/guest/region/household 상태를 운영 관점에서 봄
- push/export와 이어져야 함

### Carts
- 저장카트/구매흐름 운영 관찰
- export와 operator-only signals 제공

### Scan Ops
- OCR 품질/실패/교정 현황 관찰
- failure triage, correction pattern 확인

### Push
- compact campaign console
- direct-upload audience 지원
- raw token이 아니라 user/install/device state 기반 해석

### Ads
- campaign row가 source of truth
- slot pair form이 아니라 row-based operator sheet
- audience + region targeting 지원
- workspace / performance / setup route 분리

### Content
- runtime copy와 public/app text의 구조화 편집면
- My family-share, account deletion, footer/support copy까지 관리

### Config
- runtime flags, health, storage/path, integration status 확인

### Explore
- decision surface 운영 설정
- section/state/order/offer 관련 운영 제어

## 5. current accepted implementations

### Users
- region CRM / household summary / operator household actions 노출
- detail에서 member list / invite summary / disconnect/disband 지원

### Push
- audience preview
- segment preview
- broadcast
- push device readiness/status 확인

### Ads
- route-separated views: setup / status / efficiency
- sheet density 우선
- `slot`은 row discriminator
- `sortOrder`는 persisted runtime field
- `999`는 same-window random rotation 의미

### Content
- My settings/share copy
- account deletion copy
- public site / support / privacy 관련 copy surface

## 6. runtime verification discipline
- admin-web 수정 후 live served runtime refresh 필수
- public domain에서 실제 served page를 확인해야 함
- build 성공만으로 화면 성공 처리 금지

### canonical refresh
- `scripts/Cartly Runtime Refresh.command`
- 필요 시 preview 포함 refresh

## 7. household/operator rules
- destructive household action은 live user data에 바로 누르지 않는다.
- temp fixture 또는 테스트 계정으로 먼저 smoke test 한다.
- admin은 household 상태 visibility와 operator override를 제공하지만, 고객 데이터 손상 리스크를 줄이는 방식으로 검증한다.

## 8. ads/operator rules
- free-text 지역 입력은 지양
- 공식 한국 지역 picker + checkbox multi-select 방향
- overlap validation은 actionable error로 막아야 함
- 같은 slot 안에서 지역/회원상태별 bucket을 다룬다.

## 9. push/operator rules
- direct-upload audience는 raw push token 업로드를 받지 않는다.
- `userId` / `installId` 등을 서버에서 live device state로 재해석한다.
- preview 없이 대량 발송하지 않는다.

## 10. admin과 public web의 연결
public/business web copy는 source fallback만으로 끝나지 않는다.
실제 live DB content가 override할 수 있으므로 다음 둘 다 맞춰야 한다.
- 코드 fallback
- runtime/admin stored content

## 11. 관련 파일
- `admin-web/app/**`
- `admin-web/components/**`
- `admin-web/lib/mock.ts`
- `backend/app/routers/admin_*.py`
- `backend/app/services/admin_*`
- `backend/app/services/app_copy_service.py`

## 12. 앞으로 이 문서를 업데이트해야 하는 경우
- admin IA가 바뀔 때
- page role이 바뀔 때
- operator-console grammar가 바뀔 때
- household/push/ads 운영 규칙이 바뀔 때

## Related notes
- [[02_product/business-strategy]]
- [[03_backend/api-spec]]
- [[05_web/web-service]]
- [[06_infra/infra-system]]
