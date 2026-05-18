# Cartly Business Strategy

Last updated: 2026-05-18
Status: canonical
Purpose: business/product strategy reference for positioning, growth, monetization, and launch direction
Use this doc when: making product-priority, monetization, or launch-readiness decisions

## 1. 사업 한 줄 정의
Cartly는 장보기의 **기록, 회고, 재선택**을 묶는 소비자 utility product다.
핵심 가치는 “더 싸게 사게 해준다”보다 **더 나은 장보기 판단을 이어가게 해준다**에 있다.

## 2. 제품 포지셔닝

### 현재 포지션
- grocery shopping assistant
- same-intent alternative explorer
- receipt-backed shopping history tool
- family shopping collaboration utility

### 피해야 할 오해
- 일반 이커머스몰
- 쿠폰/광고 피드 앱
- 가격비교만 하는 앱
- OCR 데모 앱

## 3. 사용자 가치 구조

### 즉시 가치
- 현재 카트 정리
- 가격표/상품 스캔
- 장보기 저장

### 반복 가치
- 지난 장보기 재열람
- 자주 사는 흐름 회고
- 영수증 기반 구매 정리
- 같은 구매 의도 대체안 탐색

### household 가치
- 가족 단위 장보기 협업
- 서로 다른 기기에서 현재 카트 공동 편집

## 4. 성장/수익화 원칙

### 1) 제품 흐름 우선
광고나 제휴는 제품을 깨지 않는 범위 안에서만 붙인다.

### 2) same-intent 우선
Explore나 제안 영역은 사용자가 원래 사려던 것과 **같은 구매 의도** 안에서만 연결한다.

### 3) 사용자 탭 이후 외부 이동
외부 링크는 사용자가 명시적으로 눌렀을 때만 연다.
자동 리디렉션 금지.

### 4) 무작위 광고 피드 금지
Cartly는 콘텐츠 소비 앱이 아니라 decision-support app이다.

## 5. 현재 수익화/운영 구조

### Ads
- campaign row가 source of truth
- slot runtime은 파생 결과물
- membership state와 region targeting 지원
- specificity-first runtime selection

### Push
- CRM/segment 기반 운영 툴
- raw token이 아니라 user/install/device state 기준으로 운영

### Explore offer bridge
- editorial 추천, 대체안, 매장 문맥, 제휴 노출이 한 surface 안에서 조화롭게 동작해야 함
- generic ad feed가 아니라 같은 구매 의도 유지가 중심이어야 함

### Explore monetization lanes
현재 Explore 수익화/전환 구조는 두 레인으로 보는 것이 맞다.
1. same-intent substitution
   - 사용자가 원래 보던 상품과 같은 의도의 대체안 연결
   - active shopping / post-save 문맥에 특히 적합
2. store-context promotions
   - 특정 지역/마트 문맥이 강할 때 관련 오프라인 할인/행사 연결
   - idle planning 또는 store-context 문맥에 적합

## 6. 고객/운영 데이터 전략

### 고객 모델
한 명의 고객을 “현재 고정 지역 1개”로 보지 않는다.
대신 아래 관점으로 본다.
- 최근 활동지역
- 상위 활동지역
- 활동지역 수
- 회원 / 게스트 상태

### 운영 활용
- Ads targeting
- Push segmentation
- Users CRM drilldown
- 이후 리텐션 분석

## 7. public/business web의 역할
웹은 단순 랜딩이 아니라 아래 3가지 역할을 동시에 가진다.
1. App Review / 정책/지원 표면
2. 제안서/사업 소개 표면
3. 제품 신뢰 확보 표면

따라서 웹 카피와 구조는:
- 짧고 진실해야 하고
- 실제 앱 스크린샷을 써야 하며
- 운영중인 버전/지원 연락처를 반영해야 한다.

## 8. 지금 시점의 핵심 방어선
- guest mode 제공
- 개인정보 처리방침/지원 경로 확보
- in-app account deletion 제공
- foreground-only location 원칙 유지
- family sharing은 optional feature로 분리

## 9. 중기 전략 방향

### product deepening
- purchase-complete 기반 히스토리 품질 향상
- Explore 대체안 품질 고도화
- household 협업 경험 강화
- user-state / intent-state / store-context-state를 더 정교하게 분리한 운영

### operator deepening
- Users CRM
- Push segment console
- Ads targeting precision
- admin operator-console 완성도 강화

### launch readiness
- iOS review 통과
- Google Play launch
- 공개 웹의 제안서/신뢰도 완성

## 10. 지금 당장 중요하게 보는 지표
- guest → saved cart 생성
- member 전환
- receipt apply 사용률
- Explore 재진입률
- household 사용률
- 광고/제휴 노출의 방해도 없는 engagement

## 11. 하지 않을 것
- unrelated 추천 피드 확장
- 공격적인 광고 자동 노출
- 제품 핵심을 흐리는 리워드성 UX
- 이커머스 checkout 앱으로 방향 전환

## Related notes
- [[02_product/app-product]]
- [[04_admin/admin-system]]
- [[05_web/web-marketing-pages]]
- [[07_release/release-management]]
