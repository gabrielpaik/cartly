# Cartly Family Cart System

Last updated: 2026-05-18
Status: canonical
Purpose: member-only family sharing and shared cart system contract
Use this doc when: changing household rules, shared current cart behavior, or admin/operator handling

## 1. 목적
Cartly family cart는 단순 초대 기능이 아니라, **가족 단위 장보기 협업을 member-only로 제공하는 시스템**이다.

현재 목표는 아래 두 층으로 나뉜다.
- v1: 저장 카트 / 지난 카트 공유
- v2: 현재 카트 동시 편집 협업

## 2. 기본 원칙
- 가족공유는 **회원만** 사용 가능하다.
- guest / non-household 사용자는 기존 local-only 흐름을 유지한다.
- household는 현재 사용자 세션과 분리된 독립 상태를 가진다.
- owner와 member의 해제 의미는 다르다.

## 3. 용어
- `household`: 가족공유 그룹
- `owner`: household 생성자 / 관리자
- `member`: 참여 구성원
- `inviteCode`: household 참여 코드
- `shared current cart`: household 공동 현재 카트

## 4. 현재 범위

### v1에서 제공되는 것
- invite code 생성
- invite code 참여
- household 상태 조회
- shared saved/past cart visibility
- owner-only mutation enforcement

### v2에서 추가된 것
- shared current cart item add
- shared current cart item update
- shared current cart item delete
- shared current cart clear
- 여러 기기에서 practical concurrent use

## 5. 현재 사용자 규칙

### 게스트
- 가족공유 불가
- 현재 카트 local only
- shared current cart 접근 불가

### 회원이지만 household 없음
- invite code 생성 가능
- 코드로 household 참여 가능
- 현재 카트는 local only

### household member
- 현재 카트는 remote shared current cart 사용
- 저장 카트/지난 카트 공유 가시화
- household 상태는 My 페이지에서 관리

## 6. 참여 / 해제 규칙

### 생성
- owner가 invite code를 만든다.
- 코드 생성/새로고침/복사가 가능하다.

### 참여
- member는 invite code 입력으로 참여한다.
- 잘못된 코드, 만료 코드, 자기 household 중복 참여는 서버에서 막는다.

### 해제 의미
- owner `공유 해제`: household 전체 해체
- member `공유 해제`: 본인만 나가기

## 7. 현재 카트 동기화 시스템

### 채택된 방식
현재 v2는 websocket이 아니라 **polling 기반 shared draft cart**다.

### 왜 이 방식을 썼는가
- 첫 출시는 구현 복잡도보다 안정성을 우선
- household 협업이 실제로 usable 한지 먼저 검증 가능
- obvious clobbering을 줄이면서도 빠르게 배포 가능

### 핵심 규칙
- item-level identity를 사용한다.
- 같은 item edit 충돌은 first pass에서 사실상 last-write-wins다.
- 서로 다른 item 추가는 최대한 보존한다.
- polling이 직후의 local mutation을 덮어쓰지 않도록 완충이 필요하다.

## 8. 현재 데이터 모델

### 주요 테이블
- `households`
- `household_memberships`
- `household_current_carts`
- `household_current_cart_items`

### 관련 앱 모델/저장소
- `HouseholdState`
- `CurrentCartStore`
- `RemoteHouseholdRepository`
- `RemoteCurrentCartRepository`

## 9. API

### household 상태
- `GET /v1/households/me`
- `POST /v1/households/invite-code`
- `POST /v1/households/join`
- `POST /v1/households/leave`

### shared current cart
- `GET /v1/households/current-cart`
- `POST /v1/households/current-cart/items`
- `PATCH /v1/households/current-cart/items/{item_id}`
- `DELETE /v1/households/current-cart/items/{item_id}`
- `DELETE /v1/households/current-cart`

## 10. 현재 카트 저장 시 규칙
- household shared current cart를 저장 카트로 넘기면 **shared current cart는 비워진다**.
- 저장된 결과는 household의 다음 장보기 재시작 맥락에 쓰일 수 있다.

## 11. 세션 / 계정 안전성 규칙
- sign-out 시 household 상태를 정리해야 한다.
- account deletion 시 household 상태를 정리해야 한다.
- user switch 시 이전 household 상태가 남아 있으면 안 된다.

## 12. 운영 규칙
- admin Users에서 household 상태, 멤버 수, invite 요약을 볼 수 있어야 한다.
- destructive admin action은 라이브 사용자 데이터에서 함부로 누르지 않는다.
- disconnect/disband는 temp fixture나 테스트 데이터로 먼저 검증한다.

## 13. 현재 구현 판단
현재 family cart 시스템은 다음 수준까지 도달했다.
- member-only gating 완료
- invite/join/leave/disband 흐름 구현 완료
- shared saved/past cart visibility 구현 완료
- shared current cart v2 구현 및 live smoke test 완료
- public app proxy allowlist 반영 완료

## 14. 알려진 한계
- websocket 기반 실시간 동기화는 아직 없다.
- same-item 동시 수정 충돌 해결은 고급 CRDT 수준이 아니다.
- `recentScans`, `consideredItems`는 현재 local-only다.

## 15. 다음 확장 후보
- websocket 또는 push-assisted sync
- household activity log
- household별 장보기 역할 분담
- owner moderation / invite policy 강화

## Related notes
- [[02_product/app-product]]
- [[03_backend/realtime-sync-system]]
- [[03_backend/api-spec]]
- [[04_admin/admin-system]]
