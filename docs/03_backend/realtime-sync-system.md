# Cartly Realtime Sync System

Last updated: 2026-05-18
Status: canonical
Purpose: shared current-cart sync contract for household collaboration
Use this doc when: changing sync behavior, conflict handling, or shared cart lifecycle rules

## 1. 범위
이 문서는 Cartly의 **공동 현재 카트 동기화 시스템**을 설명한다.
현재 범위는 household shared current cart이며, full websocket realtime system은 아직 아니다.

## 2. 현재 채택 모델
- transport: polling
- state authority: backend DB
- sync unit: item-level
- conflict model: practical last-write-wins
- guest/non-household: local-only 유지

## 3. 왜 polling을 먼저 썼는가
- household 협업을 빠르게 실사용 가능한 수준으로 출시하기 위해
- websocket 운영 복잡도 없이 핵심 협업 가치 검증 가능
- 저장/편집/삭제의 기본 동작을 먼저 안정화하기 위해

## 4. source of truth
### household member
- source of truth는 `household_current_carts` + `household_current_cart_items`
- 앱 로컬은 캐시/UX 보조일 뿐 최종 기준이 아니다.

### guest / non-household
- 기존 `CurrentCartStore` local state가 source of truth

## 5. item identity
공동 현재 카트에서는 각 item이 안정적인 `id`를 가져야 한다.
이유:
- add/update/delete를 row 단위로 식별해야 함
- polling 중 같은 상품명이라도 서로 다른 row를 구분해야 함
- 동시 편집에서 merge/clobber를 줄여야 함

현재 원칙:
- item id는 timestamp-only가 아니라 random suffix가 섞인 안정 id를 쓴다.
- backend add는 기존 item id가 오면 idempotent update처럼 동작할 수 있다.

## 6. 앱 측 동기화 규칙
- household 상태이면 remote current cart를 사용한다.
- local mutation 직후 polling snapshot이 바로 덮어쓰지 않도록 mutation in-flight / recent-mutation cooldown을 둔다.
- write 성공 후 server snapshot을 다시 적용한다.

## 7. backend 측 동기화 규칙
- household member만 current cart API를 사용할 수 있다.
- cart가 없으면 household 기준으로 draft cart를 생성한다.
- item update/delete는 household 범위 안에서만 동작한다.
- clear는 household cart item rows를 비운다.

## 8. API 계약

### read
`GET /v1/households/current-cart`

반환 개념:
- `shared: true/false`
- `cart.householdId`
- `cart.updatedByUserId`
- `cart.createdAt`
- `cart.updatedAt`
- `cart.items[]`

### write
- add: `POST /v1/households/current-cart/items`
- patch: `PATCH /v1/households/current-cart/items/{item_id}`
- delete item: `DELETE /v1/households/current-cart/items/{item_id}`
- clear cart: `DELETE /v1/households/current-cart`

## 9. clear/save 규칙
- shared current cart를 저장 카트로 넘기면 shared current cart는 비워진다.
- 이 동작은 household 모두에게 공통 결과로 보인다.

## 10. teardown 규칙
아래 경우 shared current cart orphan row가 남으면 안 된다.
- owner disband
- member leave 후 마지막 멤버 제거
- admin disconnect/disband
- account deletion

현재 cleanup 로직은 household service / admin user service에서 함께 처리한다.

## 11. 알려진 한계
- websocket처럼 sub-second realtime은 아니다.
- 같은 item을 거의 동시에 수정하면 고급 merge 없이 마지막 write가 이길 수 있다.
- recentScans / consideredItems는 공유되지 않는다.
- offline-first 정교한 병합은 아직 없다.

## 12. 다음 확장 후보
- websocket 또는 SSE
- mutation revision / version check
- household activity feed
- sync conflict notice UX
- shared recent scan candidates

## 13. 관련 파일
- `backend/app/services/household_current_cart_service.py`
- `backend/app/routers/households.py`
- `backend/app/services/household_service.py`
- `lib/services/current_cart_store.dart`
- `lib/services/remote_current_cart_repository.dart`
- `lib/pages/home_page.dart`
- `lib/pages/home_page_cart_controller.dart`
- `test/current_cart_item_identity_test.dart`

## Related notes
- [[02_product/family-cart-system]]
- [[03_backend/database-schema]]
- [[03_backend/api-spec]]
