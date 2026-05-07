# Cartly visual foundation v1

작성일: 2026-05-07
목적: 화면별 개별 polish가 아니라, Cartly 전반의 강조 규칙과 카드 문법을 통일하기 위한 1차 기준

---

## 왜 지금 이게 필요한가

현재 Cartly는 방향은 좋다.
문제는 각 화면이 같은 제품처럼 동작은 하지만, 아직 같은 시스템처럼 보이지는 않는다는 점이다.

특히 현재 코드 기준으로 보이는 패턴은 이렇다.

- `FontWeight.w800`, `w900` 사용 비율이 높다.
- radius가 `12 / 14 / 16 / 18 / 20 / 24 / 999`까지 넓게 퍼져 있다.
- `Colors.grey.shade100` 기반 카드가 많고, 중요한 카드도 덜 중요한 카드도 비슷한 톤으로 보인다.
- 빨간 accent(`0xFFE31837`)가 강한 대신, 강조 단계가 1단계로 뭉개진다.

즉, 문제는 예쁨 부족보다 **강조 체계 부족**이다.

---

# 1. Type scale

## 원칙
- 굵기로 해결하지 말고, 크기와 간격으로 먼저 hierarchy를 만든다.
- 한 화면에서 `w900`는 정말 필요한 headline/price/strong CTA에만 쓴다.
- 기본 본문은 `w500~w600`이면 충분하다.

## 권장 scale

### Page
- pageDisplay
  - 30~32
  - w700
  - brand title 전용
- pageTitle
  - 24
  - w800
- pageSubtitle
  - 14
  - w500
  - line-height 1.45~1.55

### Section
- sectionTitle
  - 18
  - w800
- sectionSubtitle
  - 13
  - w500
  - color: neutral secondary

### Card
- cardTitle
  - 15~16
  - w700~w800
- cardBody
  - 13~14
  - w500~w600
- cardMeta
  - 11~12
  - w600
- badgeLabel
  - 11
  - w700~w800

### Price / Key numbers
- priceStrong
  - 18~24
  - w800
- priceInline
  - 14~16
  - w700

## 바로 적용할 downshift
- 기존 `section title w900 -> w800`
- 기존 `card title w900 -> w700 or w800`
- 기존 `body w600 -> 유지 가능`, 다만 남발 금지
- 기존 `meta w700/w800 -> w600~w700`

---

# 2. Surface hierarchy

## 원칙
카드가 많아도 같은 회색 박스만 반복되면 hierarchy가 죽는다.
중요도에 따라 surface를 나눈다.

## 레벨
- Surface 0
  - page background
  - pure white
- Surface 1
  - 일반 정보 카드
  - very light neutral
- Surface 2
  - 편집중, 선택됨, 강조된 작업 영역
  - slight tint or border emphasis
- Surface Brand
  - 강한 주목이 필요한 hero / total bar / 핵심 CTA
  - cartly red 사용
- Surface Contrast
  - promo / external offer / contrast section
  - 제한적으로만 사용

## 현재 기준에서의 적용
- `Colors.grey.shade100` 카드는 기본적으로 Surface 1
- 펼쳐진 current cart item은 Surface 2로 승격
- Explore hero는 Surface Brand 유지
- 검정 offer card는 Surface Contrast로 분리하되 남용 금지

---

# 3. Radius scale

## 문제
지금은 12, 14, 16, 18, 20, 24가 자주 혼용된다.
차이가 작아서 의도보다 우연처럼 보일 가능성이 높다.

## 권장 기준
- 12: compact control, badge container, small rows
- 16: standard card
- 20: hero / sheet / high-emphasis container
- 999: pill only

## 정리 규칙
- 14, 18은 가능하면 신규 사용을 줄인다.
- 일반 카드 기본값은 16으로 통일한다.
- 작은 row 안쪽 interactive zone은 12를 쓴다.

---

# 4. Card taxonomy

## 1) Action card
용도: 당장 행동 유도
예: 홈의 직접 추가, 탐색 진입 row

구성:
- title
- 짧은 설명 1줄
- 명확한 action affordance

## 2) Decision card
용도: 비교/판단
예: Explore decision inbox

구성:
- item or decision title
- reason 1줄
- badge 최대 1~2개
- CTA 1개

## 3) Info card
용도: 상태/안내
예: empty state, helper info

구성:
- title
- body
- action optional

## 4) Promo / compare card
용도: external offer, 비교 후보

구성:
- provider
- 핵심 절약/대안 신호
- 외부 이동 action

주의:
- 광고처럼 보이기보다 `대안 제안`으로 읽혀야 함

## 5) Editable cart card
용도: 현재 카트 작업 영역

구성:
- collapsed: 이름 / 수량 / 금액 / edit affordance
- expanded: display name edit / original name / quantity context / apply action

---

# 5. CTA hierarchy

## Primary
- 제품의 현재 핵심 행동
- 예: 카트 저장, 상품명 적용
- filled, strong emphasis

## Secondary
- 같은 문맥에서 보조 행동
- 예: 현재 카트 이어서 보기, 검토 열기
- outlined or tonal

## Tertiary
- 덜 중요한 inline action
- 예: 접기, 나중에 보기
- text button

## 규칙
- 한 카드 안에 Primary는 1개
- badge가 CTA처럼 보이면 안 됨
- Explore에서는 CTA보다 판단 내용이 먼저 읽혀야 함

---

# 6. State language

## 홈/스캔 계열 통일안
- 촬영 완료
- 업로드 중
- 분석 중
- 검토 대기
- 담기 완료
- 처리 실패

## 원칙
- 상태명은 2~4음절 중심
- 현재 진행 / 다음 행동이 보이게
- 한 상태에서 비슷한 뜻의 다른 표현을 섞지 않기

---

# 7. 화면별 1차 적용 원칙

## Home
- 상단 title/subtitle weight 완화
- section header 강조 정리
- 하단 Explore 진입을 text가 아니라 soft action row로 승격

## Current cart
- collapsed를 2층 구조에 가깝게 재배치
- edit affordance를 명시적으로 드러내기
- expanded state를 border/tint로 구분

## Explore
- hero를 제외한 카드의 밀도를 낮추기
- decision card는 본문 2줄 안팎, badge 2개 이하
- contrast offer card tone을 과한 광고 느낌 없이 조정

---

# 8. 지금 바로 적용할 순서

1. SectionHeader type 정리
2. Home title/subtitle + Explore entry row 정리
3. Current cart item card visual grammar 정리
4. Explore decision/offer card 톤 재정리

---

# 9. 성공 기준

이 foundation이 잘 적용되면,

- 같은 화면 안에서 무엇이 가장 중요한지 더 빨리 보이고
- 화면마다 개별 카드가 아니라 같은 제품 규칙으로 느껴지고
- 새 기능이 붙어도 일관성이 덜 무너진다.

핵심은 `더 화려하게`가 아니라,
**강조 단계를 줄이고 규칙을 더 선명하게 만드는 것**이다.
