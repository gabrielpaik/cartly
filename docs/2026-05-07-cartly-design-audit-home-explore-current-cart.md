# Cartly 디자인 audit v1

작성일: 2026-05-07
기준서: `docs/2026-05-07-cartly-design-evaluation-rubric.md`
범위: Home / Explore / Current cart
근거: 현재 구현 코드, preview state, sample data 기준 1차 audit

---

## 총평
지금 Cartly는 예전보다 훨씬 덜 혼란스럽고, 특히 Home의 실행 중심 구조와 Current cart의 inline 편집 방향은 맞다.
다만 아직은 화면들이 하나의 강한 디자인 시스템 아래 묶여 있다기보다,
`좋은 의도의 카드 여러 장`이 모인 상태에 가깝다.

가장 큰 문제는 3가지다.

1. 타이포와 강조 강도가 전반적으로 너무 세다.
2. gray card + red accent 패턴이 거의 모든 화면에서 반복되어 hierarchy가 둔해진다.
3. Explore가 구조적으로는 맞아가고 있지만, 아직 `판단 workspace`라기보다 `카드 피드`처럼 느껴진다.

반대로 가장 좋은 방향 3가지는 이거다.

1. Home을 실행 중심으로 둔 것
2. Explore를 decision surface로 분리한 것
3. Current cart에서 상품명 편집을 inline disclosure로 바꾼 것

---

# 1. Home

## 총평
Home은 현재 Cartly에서 가장 product intent가 잘 살아 있는 화면이다.
사용자가 지금 해야 할 일, 즉 스캔하고, 담고, 확인하고, 저장하는 흐름이 비교적 명확하다.
다만 section 간 위계는 아직 다소 평평하고, foundation 차원에서 카드/텍스트 강조 규칙이 조금씩 흔들린다.

## 점수
- Information hierarchy: 4.1
- State clarity: 3.8
- Action flow quality: 4.2
- Foundation consistency: 3.3
- Component discipline: 3.4
- Content system quality: 3.5
- Accessibility and legibility: 3.5
- Brand-product fit: 4.0

평균: **3.73**

## 잘 된 점 3개
1. `새 상품 추가 → 스캔 보관함 → 현재 카트 → 저장` 흐름이 명확하다.
2. 하단 Total bar가 저장 행동을 분명하게 붙잡아준다.
3. 최근 스캔과 현재 카트가 분리되어 있어 사용자가 작업 상태를 이해하기 쉽다.

## 문제 3개
1. 섹션은 분리되어 있지만 전체 hierarchy가 아직 너무 평평하다.
   - section header, gray card, red CTA가 반복되어 어느 블록이 더 중요한지 시각적 차이가 크지 않다.
2. 타이포 weight가 전반적으로 강하다.
   - 800/900급 weight 사용 비율이 높아 한 화면 안에서 강조의 차등이 줄어든다.
3. `탐색에서 도움 받기`가 현재는 너무 약하다.
   - 문구만 남겨둔 결정은 방향상 맞지만, 지금은 화면 말미에 뜬금없는 꼬리문장처럼 남아 있다.

## 바로 고칠 것
- Home 마지막의 `탐색에서 도움 받기`를 단순 텍스트가 아니라, 아주 가벼운 action row 또는 soft tile로 승격
- section spacing 규칙 재정리, 각 블록의 vertical rhythm 통일
- heading / subheading / body / meta의 type weight를 한 단계씩 낮춰 hierarchy 정제

## 나중에 시스템으로 고칠 것
- Home 전용 카드가 아니라 앱 전반 공용 section-shell 규칙 정의
- Total bar, FilledButton, OutlinedButton의 역할 체계 재정의
- 스캔/카트/저장 상태를 공통 status language로 묶기

---

# 2. Explore

## 총평
Explore는 정보구조 방향은 맞다.
지금은 예전보다 훨씬 덜 산만하고, `결정 인박스` 중심 구조도 product 전략과 맞는다.
하지만 시각적으로는 아직 `판단을 돕는 surface`라기보다 `서로 다른 카드 묶음`에 가깝다.
특히 hero, inbox card, repeat card, offer card가 각자 존재감은 있지만 하나의 질서로 묶였다는 느낌은 아직 약하다.

## 점수
- Information hierarchy: 3.6
- State clarity: 3.9
- Action flow quality: 3.7
- Foundation consistency: 3.1
- Component discipline: 3.0
- Content system quality: 3.5
- Accessibility and legibility: 3.2
- Brand-product fit: 4.1

평균: **3.51**

## 잘 된 점 3개
1. 쇼핑 중 Explore를 `결정 인박스` 중심으로 좁힌 것은 매우 좋다.
2. `홈에서 실행, Explore에서 판단` 경계가 카피와 구조에서 드러난다.
3. 비교 후보와 반복 구매를 같은 쇼핑 맥락 안에서 다루려는 전략이 분명하다.

## 문제 3개
1. 시각 시스템이 아직 카드 피드에 가깝다.
   - hero, inbox, repeat, offer가 모두 카드지만 우선순위와 역할 차이가 충분히 구조화되어 보이지 않는다.
2. 검정 offer card는 존재감은 강하지만 주변 시스템과 약간 분리되어 보일 위험이 있다.
   - 광고/프로모션 surface인지, 비교 decision card인지 인상이 갈릴 수 있다.
3. 카피 길이와 배지 수가 누적되면서 decision scan speed가 떨어질 수 있다.
   - 배지, 이유 라벨, 본문, CTA가 카드마다 모두 붙으면 빠른 장보기 상황에서 읽기 피로가 생긴다.

## 바로 고칠 것
- Explore 카드 유형을 3종 정도로 축소 정의
  - hero
  - decision card
  - compare/promo card
- decision inbox 카드의 본문 길이와 badge 수 상한 정하기
- 검정 offer card의 tone을 전체 시스템과 다시 맞추기, 너무 광고처럼 보이지 않게 조정

## 나중에 시스템으로 고칠 것
- Explore state별 layout grammar 문서화
  - active shopping
  - post-save
  - idle
  - store-context
- decision card용 semantic token 정의
  - urgency
  - relevance
  - savings/comparison signal
- comparison/promo surface의 disclosure 규칙 통일

---

# 3. Current cart

## 총평
Current cart는 이번 변경으로 방향이 확실히 좋아졌다.
특히 `긴 상품명은 카드 자체를 펼쳐 편집`하게 바꾼 것은 Cartly의 실제 장보기 맥락에 맞는 좋은 결정이다.
다만 collapsed 상태에서 정보 배치가 여전히 약간 빡빡하고, 수정 가능성(editability)이 시각적으로 아주 명확하지는 않다.

## 점수
- Information hierarchy: 3.8
- State clarity: 4.1
- Action flow quality: 4.2
- Foundation consistency: 3.3
- Component discipline: 3.6
- Content system quality: 3.8
- Accessibility and legibility: 3.4
- Brand-product fit: 4.0

평균: **3.78**

## 잘 된 점 3개
1. 상품명 수정이 modal/bottom sheet가 아니라 inline이라 맥락이 안 끊긴다.
2. 원본 인식명 보존과 표시명 수정이 분리되어 product correctness와 UX를 둘 다 챙겼다.
3. 수량 수정, 가격 확인, 삭제, 이름 수정이 모두 같은 working area 안에서 이뤄진다.

## 문제 3개
1. collapsed row의 좌우 밀도가 높다.
   - 긴 이름, 수량 조절, 총액이 한 줄 근처에서 경쟁해 작은 화면에서 답답해질 수 있다.
2. edit affordance가 충분히 명시적이지 않다.
   - 사용자가 `이름을 눌러 펼치면 수정된다`를 바로 학습하지 못할 수 있다.
3. expanded state가 기능적으로는 좋아졌지만, 시각적으로는 `편집 모드`라는 느낌이 조금 약하다.
   - 펼쳐졌을 때 surface/border/emphasis 차이가 더 있어도 된다.

## 바로 고칠 것
- collapsed card를 2층 구조로 재검토
  - 1행: 이름
  - 2행: 수량 조절 / 가격 / 보조 액션
- 이름 영역에 `수정` affordance를 조금 더 명확히 추가
- expanded state에 편집중임을 보여주는 border 또는 tonal emphasis 추가

## 나중에 시스템으로 고칠 것
- cart item card 전용 layout spec 정의
- editable disclosure pattern을 다른 화면에서도 재사용 가능한 공통 패턴으로 정리
- 향후 정상가/할인가 2층 가격 모델을 수용할 수 있게 정보 슬롯 구조화

---

# 즉시 수정 5개

1. **타이포 weight 전반 다운시프트**
- 900/800 남용을 줄이고 hierarchy를 회복

2. **Home 마지막 Explore 진입부 재설계**
- 현재 문장형 꼬리 대신 soft action row/tile로 정리

3. **Current cart collapsed layout 2행화 검토**
- 긴 이름과 조작부 충돌 완화

4. **Explore decision card copy 압축**
- badge/body/cta 길이 상한 정하기

5. **Offer card tone 재정의**
- 검정 카드가 광고처럼 튀지 않게 전체 시스템 안으로 회수

---

# 시스템 개선 5개

1. **Foundation token 정리**
- radius 12/14/16/18/20 사용 기준 정리
- gray surface 단계 정의

2. **Type scale / emphasis scale 정리**
- page title / section title / card title / body / meta 규칙 표준화

3. **Card taxonomy 정리**
- action card
- decision card
- info card
- promo card
- editable cart card

4. **State language 정리**
- 촬영 완료 / 분석 중 / 검토 대기 / 담기 완료 등 product-wide 용어 통합

5. **CTA hierarchy 정리**
- primary / secondary / tertiary / text action 역할 정의

---

# 추천 다음 순서

## 1차 구현 우선순위
1. type scale 정리
2. Home 하단 Explore 진입부 정리
3. Current cart collapsed/expanded visual refinement
4. Explore card taxonomy 정리

## 그 다음
5. Explore 전체 visual grammar 재정리
6. My / Login / Receipt compare까지 같은 rubric으로 확장 audit

---

## 결론
현재 Cartly는 방향을 잘 잡았다.
이제 필요한 건 화면별 예쁜 수정이 아니라,
**강조 강도, 카드 유형, 상태 언어, CTA 체계를 시스템으로 다시 묶는 일**이다.

특히 다음 단계는
`더 화려하게`가 아니라
`더 적은 규칙으로 더 많은 화면을 일관되게 설명하게 만들기`
쪽이 맞다.
