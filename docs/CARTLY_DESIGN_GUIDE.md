# Cartly Design Guide

작성일: 2026-05-07
상태: living document

## 목적

이 문서는 Cartly를 화면별로 예쁘게 손보는 메모가 아니라,
앞으로 기능이 추가되어도 같은 제품처럼 보이게 만드는 운영용 디자인 기준서다.

핵심 목표는 4가지다.

1. Home, Explore, My, Login, Receipt compare가 같은 제품 문법으로 보이게 한다.
2. 디자인 결정을 취향이 아니라 hierarchy, state, action 기준으로 내리게 한다.
3. 새 화면이나 새 기능이 들어와도 기존 foundation을 재사용하게 한다.
4. 앱 변경이 생기면 admin preview도 같은 턴에 갱신되게 한다.

---

## Product framing

Cartly는 generic 쇼핑앱이 아니다.
Cartly는 **장보기 decision partner**다.

따라서 화면별 역할은 아래처럼 분명해야 한다.

- **Home** = 실행
- **Explore** = 판단
- **My** = 장보기 기록 허브
- **Login** = 기록 연속성을 얻기 위한 진입점
- **Receipt compare** = 저장한 장보기와 실제 결제 결과를 확인하는 검증면

이 역할을 흐리는 UI는 예뻐 보여도 Cartly 방향과 맞지 않는다.

---

## Core principles

### 1. 굵기로 해결하지 말고 hierarchy로 해결한다
- `w800`, `w900`를 늘리는 대신
  - 크기
  - 간격
  - 표면 대비
  - 위치
  로 우선순위를 만든다.

### 2. 카드가 많아도 모두 같은 회색 박스가 되면 안 된다
- Surface는 역할별로 나뉘어야 한다.
- 정보 카드, 작업 카드, 강조 카드, contrast 카드가 구분되어야 한다.

### 3. Explore는 help 탭이 아니라 decision surface다
- 같은 구매 의도의 대안을 보여주는 구조여야 한다.
- unrelated 추천 피드는 금지한다.

### 4. My는 profile보다 기록 허브다
- 계정보다 지난 장보기, 최근 저장, 다시 시작 흐름이 먼저 읽혀야 한다.

### 5. 디자인은 앱만의 문제가 아니다
- app UI가 바뀌면 admin preview도 같은 턴에 갱신한다.
- stale admin preview는 디자인 검토를 망친다.

---

## Visual foundation

### Typography

#### Page
- page hero: 30~32 / `w700`
- page subtitle: 14 / `w500` / line-height 1.45~1.55

#### Section
- section title: 18 / `w800`
- section subtitle: 13 / `w500`

#### Card
- card title: 15~16 / `w700~w800`
- card body: 13~14 / `w500~w600`
- card meta: 11~12 / `w600~w700`

#### Price / strong numbers
- strong price: 18~24 / `w800`
- inline price: 14~16 / `w700`

### Radius
- `12`: compact control, badge, inner row
- `16`: standard card
- `20`: hero / high emphasis block
- `999`: pill only

신규 작업에서 `14`, `18`, `24` 같은 반쯤 애매한 radius는 가급적 늘리지 않는다.

### Surface levels
- **Surface 0**: page background, white
- **Surface 1**: default information card
- **Surface 2**: selected, expanded, editing state
- **Surface Brand**: hero, strong CTA
- **Surface Contrast**: partner offer, contrast promo

---

## Current shared UI primitives

현재 코드 기준 공통 foundation은 여기서 관리한다.

- `lib/app/cartly_ui.dart`
  - `CartlyColors`
  - `CartlyRadii`
  - `CartlyText`
  - `CartlyButtonStyles`
- `lib/widgets/cartly_badge.dart`
- `lib/widgets/cartly_surface_card.dart`
- `lib/widgets/section_header.dart`

규칙:
- 새 화면을 만들 때는 먼저 여기서 해결 가능한지 본다.
- 화면 안에서만 쓰는 임시 스타일을 먼저 늘리지 않는다.
- 같은 역할의 UI가 2번 이상 생기면 공통화 후보로 본다.

---

## Component rules

### Buttons

#### Primary
- 현재 화면의 핵심 행동 1개만
- filled
- 예: 저장, 적용, 다시 촬영

#### Secondary
- 보조 행동
- outlined or tonal
- 예: 최근 저장 카트 다시 열기

#### Tertiary
- inline text action
- 예: 숨긴 offer 다시 보기

규칙:
- 카드 하나에 primary는 가능하면 1개
- badge가 CTA처럼 보이면 안 됨
- CTA보다 판단 내용이 먼저 읽혀야 하는 화면에서는 본문 hierarchy를 우선

### Badge
- badge는 상태/분류/문맥 표시용
- 클릭 유도처럼 보이지 않게 유지
- 한 카드에서 badge 1~2개가 기본, 많아지면 정보 구조를 다시 본다

### Surface card
- 기본 정보 카드는 `CartlySurfaceCard` 우선 사용
- card별 예외 스타일은
  - gradient
  - border
  - backgroundColor
  정도만 override

### Section header
- 모든 주요 섹션은 `SectionHeader` 문법을 우선 사용
- 섹션마다 완전히 다른 heading 스타일을 만들지 않는다

---

## Screen grammar

### Home
- 가장 먼저 보여야 하는 것은 지금 담기, 보기, 저장하기다
- 하단 Explore 연결은 꼬리문장보다 action row가 낫다
- current cart는 real working area처럼 보여야 한다

### Explore
- hero는 방향 제시
- 그 아래 카드는 판단과 대안 제시
- offer는 ad feed처럼 보이지 않고 same-intent decision support처럼 보여야 한다

### My
- 상단 허브는 identity보다 기록과 재진입을 강조
- 최근 저장한 장보기가 있으면 그 재시작 흐름이 먼저 읽혀야 한다

### Login
- 왜 로그인하는지 설명은 짧고 현실적이어야 한다
- 혜택은 과장보다 continuity 중심

### Receipt compare
- 목적은 한 줄로 이해되어야 한다
- 총액 비교와 참고 상세는 분리되어야 한다
- 비구매 line이 상품처럼 읽히면 안 된다

---

## Content and tone

- 짧고 사람 말처럼 쓴다.
- 같은 상태를 화면마다 다른 단어로 부르지 않는다.
- empty, loading, processing, error, success 카피는 같은 제품 톤을 유지한다.
- Explore, Home, My가 서로 다른 서비스처럼 말하면 안 된다.

---

## Design workflow rule

Cartly 작업에서는 아래를 기본 workflow로 고정한다.

1. app UI 변경
2. 관련 admin surface 확인 또는 반영
3. `admin-web/public/app-preview` 재빌드
4. admin에서 바로 볼 체크포인트 정리

즉, **app만 바꾸고 admin은 나중에** 금지.

---

## Admin preview rule

디자인 검토는 실제 코드와 admin preview가 동시에 맞아야 의미가 있다.

확인 규칙:
- UI가 바뀌면 `/content` preview 기준으로 다시 본다.
- preview가 stale하면 먼저 rebuild한다.
- preview에서만 깨지는 인자/상태 문제도 production-adjacent bug로 취급한다.

---

## When to extract a shared component

아래 중 2개 이상에 해당하면 공통화 후보다.

- 같은 구조가 2개 이상 화면에서 반복된다
- 색/여백/반경 규칙이 같아야 한다
- 앞으로도 새 화면에서 반복될 가능성이 높다
- 리뷰할 때 “이 화면만 예외” 설명이 길어진다

---

## Current next extraction candidates

1. small CTA row / inline action row
2. helper / status info card
3. compare / decision card skeleton
4. empty-state block
5. page hero block

---

## Review checklist

화면 수정 후 항상 본다.

- 지금 가장 중요한 정보가 먼저 보이는가
- CTA hierarchy가 맞는가
- 같은 역할의 card/button/badge가 같은 문법인가
- state wording이 다른 화면과 충돌하지 않는가
- admin preview에서도 같은 상태가 보이는가

---

## Related docs

- `docs/2026-05-07-cartly-design-evaluation-rubric.md`
- `docs/2026-05-07-cartly-design-audit-home-explore-current-cart.md`
- `docs/2026-05-07-cartly-visual-foundation-v1.md`

이 문서는 foundation과 audit를 묶는 상위 운영 문서로 유지한다.
