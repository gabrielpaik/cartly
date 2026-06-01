# Cartly Design Guide

작성일: 2026-05-07 (v2)
상태: living document

## 목적

이 문서는 Cartly를 화면별로 예쁘게 손보는 메모가 아니라,
앞으로 기능이 추가되어도 같은 제품처럼 보이게 만드는 운영용 디자인 기준서다.

핵심 목표는 4가지다.

1. Home, Explore, My, Login, Receipt compare가 같은 제품 문법으로 보이게 한다.
2. 디자인 결정을 취향이 아니라 hierarchy, state, action 기준으로 내리게 한다.
3. 새 화면이나 새 기능이 들어와도 기존 foundation을 재사용하게 한다.
4. 앱 변경이 생기면 admin preview도 같은 턴에 갱신되게 한다.

### v2에서 추가/변경된 것

- **Color tokens** 섹션 신설 — brand red, sub brand green, contrast 토큰 확정
- **Surface levels**에 구체 hex 값 부여
- **Icons** 섹션 신설 — Material Symbols Rounded 채택
- semantic 컬러는 brand와 hue를 분리한다는 규칙 명시
- brand surface 위 보조 텍스트는 alpha-white 금지, neutral gray 단일 토큰으로 통일

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

### 6. brand color와 semantic color는 분리한다
- Cartly red는 brand·promo·CTA용이지 error/danger가 아니다.
- Cartly green은 sub-brand·확인·매칭용이지 generic success가 아니다.
- semantic은 별도 hue로 정의해서 hue 자체에 의미를 박지 않는다 (Color tokens 섹션 참고).

---

## Visual foundation

### Color

Cartly의 컬러 운영은 **소수 정예 + 고대비** 원칙이다.
brand 2개 + contrast 1개 + neutral muted 1개 + semantic 4개. 그 외는 만들지 않는다.

#### Brand Primary — Cartly Red

대표 stop: `500` / `#E31736`. 5 stop으로만 운영한다.

| stop | hex | 쓰임 |
|---|---|---|
| 400 | `#E73E55` | 강조 텍스트 / 아이콘 on white |
| **500** | **`#E31736`** | default fill — primary CTA, Surface Brand bg |
| 600 | `#C40D2A` | hover state |
| 700 | `#A00521` | pressed state |
| 800 | `#7A001A` | text on light tinted surface |

50/100/200/300 / 900은 정의하지 않는다. soft tint이 필요한 자리는 Surface 대안 절을 본다.

#### Sub Brand Primary — Cartly Green

대표 stop: `700` / `#185C00`. 5 stop으로만 운영한다.

| stop | hex | 쓰임 |
|---|---|---|
| 400 | `#28A30C` | inline accent |
| 500 | `#1F8A06` | filled secondary CTA |
| 600 | `#1B7503` | transition / hover-light |
| **700** | **`#185C00`** | default fill — Surface Sub-Brand, secondary border/text |
| 800 | `#114600` | hover state · text on light surface |

#### Contrast

`#111111` 단일. surface 전용. ramp 없음. 본문 텍스트 색으로 쓰지 않는다.

#### Neutral muted (on brand)

| token | hex | 쓰임 |
|---|---|---|
| `text.onBrand.primary` | `#FFFFFF` | brand·sub-brand·contrast surface 위 헤딩·본문 |
| `text.onBrand.muted` | `#D6D6D6` | brand·sub-brand·contrast surface 위 라벨·보조 텍스트 |

brand surface 위 보조 텍스트에 `rgba(255,255,255,0.x)` 같은 알파-흰색을 쓰지 않는다.
빨강 위에서는 분홍이 되고, 초록 위에서는 옅은 올리브가 된다. hue가 한 번 더 새는 것이다.

#### Semantic

semantic은 brand와 다른 hue를 강제한다.

| token | hex | 쓰임 |
|---|---|---|
| `semantic.danger` | `#B42318` | error, destructive 액션 (삭제, 되돌릴 수 없음 경고) |
| `semantic.success` | `#067647` | 완료, 검증 통과 |
| `semantic.warning` | `#B54708` | 주의, 비파괴적 경고 |
| `semantic.info` | `#175CD3` | 안내, 비활성 상태 정보 |

semantic은 작은 영역에만 쓴다 (icon, badge, helper text, border accent). 큰 surface fill은 brand가 한다.

#### Soft surface 대안

50/100을 만들지 않기로 했기 때문에, brand-tinted 옅은 배경이 필요할 때는 다음 셋 중에서 고른다. 위에서부터 권장 순서.

1. **neutral gray bg + brand accent** — gray 100 surface에 brand 500 border-left 또는 brand 800 text. 가장 일관됨.
2. **brand surface 자체를 안 쓰기** — soft 강조가 안 되면 그냥 surface 1로 두고 hierarchy를 size·weight로 잡는다.
3. **alpha utility** — 정 필요하면 `#E31736 @ 8%`처럼 알파 오버레이로 임시 처리. token 아님, 한정 사용.

#### 절대 금지

- brand surface 위에 brand color를 텍스트로 쓰는 것 (red 위 red text, green 위 green text)
- ramp 안 정의된 stop을 임의로 만들어서 쓰는 것 (예: red.350)
- 한 화면에 brand red surface와 sub-brand green surface를 인접 배치하는 것 (보색이라 진동함)
- semantic을 brand 대용으로 쓰는 것 (danger를 강조용 빨강으로, success를 OK 표시용 초록으로 갖다 쓰지 않는다)

#### WCAG 검증 (참고)

- white text on `#E31736` → 5.83:1 (AA pass for body)
- white text on `#185C00` → 12.1:1 (AAA)
- white text on `#111111` → 18.6:1 (AAA)
- `#D6D6D6` text on brand surfaces → 약 3.7:1 (decorative label tier 적합, 본문 사용 비권장)

---

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

---

### Radius
- `12`: compact control, badge, inner row
- `16`: standard card
- `20`: hero / high emphasis block
- `999`: pill only

신규 작업에서 `14`, `18`, `24` 같은 반쯤 애매한 radius는 가급적 늘리지 않는다.

---

### Surface levels

| level | bg | border | 쓰임 |
|---|---|---|---|
| **Surface 0** | `#FFFFFF` (page) | — | page background |
| **Surface 1** | `#FFFFFF` | `0.5px solid` neutral border | default information card |
| **Surface 2** | neutral gray (예: `#F1EFE8`) | optional 0.5px | selected, expanded, editing state |
| **Surface Brand** | red `#E31736` (500) | none | hero, strong CTA, today/실행 강조 |
| **Surface Sub-Brand** | green `#185C00` (700) | none | 검증면, receipt match, 결제 완료 강조 |
| **Surface Contrast** | `#111111` | none | partner offer, contrast promo |

같은 화면에서 Brand와 Sub-Brand surface를 동시에 쓰지 않는다. 한 화면 한 brand surface가 기본.

---

### Icons

#### Library: Material Symbols Rounded

근거:
- variable font 축이 Cartly의 hierarchy 어휘와 매칭됨 (`weight`, `fill`, `optical size`)
- Flutter 네이티브 지원 → `Icons.*`로 추가 패키지 없이 동작
- shopping 도메인 커버리지가 가장 넓음

스타일은 **Rounded** 고정. radius 12/16/20/999을 쓰는 가이드와 시각 일관성이 가장 좋다.

#### Variants

| 상태 | weight | fill | 비고 |
|---|---|---|---|
| default | 400 | 0 (outlined) | 기본 |
| selected / active | 400 | 1 (filled) | Surface 2 위, tab 선택 등 |
| strong emphasis | 500~600 | 1 | hero·CTA 인접 아이콘 한정 |
| disabled | 400 | 0 | 색은 neutral muted (Color 섹션 참고) |

#### Sizes

| size | 쓰임 |
|---|---|
| `16` | inline (text 옆 작게) |
| `20` | control (button 안쪽 등) |
| `24` | default (tab bar, list row) |
| `32` | hero block |

#### Color rule

아이콘은 자체 색을 안 갖는다. 동반 텍스트의 role 색을 그대로 상속한다.

- primary text 옆 → text.primary
- secondary text 옆 → text.secondary
- brand surface 위 → white 또는 `text.onBrand.muted`
- semantic helper 옆 → 같은 semantic hue

#### Spacing & layout

**아이콘 + 텍스트 gap**

icon size에 따라 gap을 다르게 둔다.

| icon size | gap | 쓰임 |
|---|---|---|
| 16 | 6 | inline (text 옆 작게) |
| 20 | 8 | control 안쪽, button label |
| 24 | 12 | list row, tab bar |
| 32 | 16 | hero block |

세로 정렬은 inline이면 baseline, block이면 center로 통일한다.
icon만 따로 색을 넣어서 텍스트보다 튀게 만들지 않는다 (Color rule 참고).

**List row 안 아이콘**

기본 list row 구조:

- leading icon slot: `24` 고정 (icon 자체도 24, 슬롯도 24, gap 12 후 텍스트)
- trailing icon: `16` (chevron, more, status). right edge에 정렬, 키우지 않는다.
- 좌우 row padding: `16~20`

leading icon이 없는 row에서도 들여쓰기는 그대로 둔다.
아이콘 있는 row와 없는 row가 같은 indent로 보여야 list가 흐트러지지 않는다.

**Empty-state 아이콘**

| 위치 | size | 색 |
|---|---|---|
| 카드 안 inline empty | `32` | `text.tertiary` |
| 섹션 empty | `40` | `text.tertiary` |
| 페이지 empty | `48~56` | `text.tertiary` |

`64`를 넘기지 않는다. 그 이상은 일러스트 영역이라 별도 검토 대상이다.
empty-state에는 brand color를 쓰지 않는다. 비어있는 상태는 액션 유도가 아니라 평온한 신호.

#### Custom SVG

기본은 Material Symbols로 끝낸다.
"Cartly다움"이 필요한 brand moment 한정으로 자체 SVG를 만들 수 있다.

현재 후보 (확정 시 추가):

- Cartly cart icon
- Receipt compare icon

자체 SVG가 만들어지면 `lib/icons/`에 두고, 사용 측은 Material Symbols 호출과 같은 인터페이스로 감싼다.

---

## Current shared UI primitives

현재 코드 기준 공통 foundation은 여기서 관리한다.

- `lib/app/cartly_ui.dart`
  - `CartlyColors` — Color tokens 섹션의 모든 hex을 반영한다 (이번 v2에서 갱신 필요)
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
- filled, brand red 500
- 예: 저장, 적용, 다시 촬영

#### Secondary
- 보조 행동
- outlined 또는 tonal, sub brand green 700 border + text
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

### Icon (component-level note)
- 단독 아이콘 버튼은 만들지 않는 게 기본. icon + label 동반.
- icon-only는 universal한 의미가 있을 때만 (close, back, more 등).

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
- 매칭 완료 강조에 Surface Sub-Brand(green 700)를 쓴다

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
- 리뷰할 때 "이 화면만 예외" 설명이 길어진다

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
- color: brand surface 위에 alpha-white나 brand-tinted 텍스트가 끼어있지 않은가
- color: semantic이 brand 대용으로 쓰이고 있지 않은가
- icon: variant가 상태와 맞는가 (default = outlined, selected = filled)
- icon: text와의 gap, list row leading slot이 size 기준에 맞는가
- icon: empty-state가 neutral 색이고 64 이내인가

---

## Related docs

- `docs/2026-05-07-cartly-design-evaluation-rubric.md`
- `docs/2026-05-07-cartly-design-audit-home-explore-current-cart.md`
- `docs/2026-05-07-cartly-visual-foundation-v1.md`
- `docs/2026-05-07-cartly-color-tokens-v1.md` (v2 신설 — Color 섹션의 단일 소스)
- `docs/2026-05-07-cartly-icon-system-v1.md` (v2 신설 — Icons 섹션의 단일 소스)

이 문서는 foundation과 audit를 묶는 상위 운영 문서로 유지한다.
