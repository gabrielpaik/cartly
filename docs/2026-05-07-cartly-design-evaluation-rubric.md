# Cartly 디자인 평가 기준서

작성일: 2026-05-07

## 목적
이 기준서는 Cartly를 화면 단위 예쁘게 다듬는 수준이 아니라,
하나의 일관된 shopping decision product로 평가하고 개선하기 위한 기준이다.

참고한 상위 방향:
- Google Material 3: 토큰, 대비, 상태, 모션, expressive hierarchy
- Apple HIG: 플랫폼 친화성, 명확성, 즉시 이해성
- LINE DS: 통일된 언어, 여백/레이아웃 규율, 컴포넌트 거버넌스
- Uber Base: content design, state clarity, motion, inclusion
- Salesforce SLDS: 복잡한 운영/정보 구조에서의 밀도, semantic structure

---

## 평가 원칙

1. Home은 실행 중심이어야 한다.
2. Explore는 decision surface여야 한다.
3. My는 프로필보다 장보기 기록 허브여야 한다.
4. 디자인은 예쁨보다 상태 이해, 행동 유도, 인지 부하 감소를 우선한다.
5. 새 화면을 예외로 만들지 말고, foundation과 component 규칙으로 해결한다.

---

## 점수 체계
각 항목을 1~5점으로 평가한다.

- 1점: 구조적으로 문제 있음, 목적과 어긋남
- 2점: 부분적으로 동작하지만 일관성/명확성이 약함
- 3점: 기본은 충족하지만 완성도가 낮음
- 4점: 목적에 잘 맞고 일관성도 좋음
- 5점: 시스템적으로 매우 잘 정리되어 있고 확장도 쉬움

권장 해석:
- 4.2 이상: 유지, 소폭 polish만
- 3.4 ~ 4.1: 개선 후보
- 2.6 ~ 3.3: 구조 개선 필요
- 2.5 이하: 우선 수정 대상

---

## 핵심 평가 축

### 1. Information hierarchy
질문: 이 화면에서 사용자가 지금 봐야 할 것과 지금 해야 할 것이 한눈에 드러나는가?

체크포인트:
- 1순위 행동이 명확한가
- 제목, 요약, 보조 설명의 위계가 분명한가
- 카드/버튼/배지의 시각적 강조가 목적과 맞는가
- 한 화면에 경쟁하는 CTA가 너무 많지 않은가

### 2. State clarity
질문: 사용자가 지금 어떤 상태인지 혼동 없이 이해할 수 있는가?

체크포인트:
- 쇼핑 중 / 검토 중 / 저장 후 / 유휴 상태가 분명한가
- 처리 중, 대기 중, 완료, 오류 상태가 섞이지 않는가
- 상태 전환 후 UI 피드백이 자연스러운가
- 같은 상태를 화면마다 다른 용어로 부르지 않는가

### 3. Action flow quality
질문: 사용자가 생각한 다음 행동으로 부드럽게 이어지는가?

체크포인트:
- add, edit, compare, save, dismiss 흐름이 끊기지 않는가
- inline edit/disclosure가 자연스러운가
- modal/bottom sheet/navigation push 사용이 과하지 않은가
- 되돌리기/취소/확인 흐름이 과하게 무겁지 않은가

### 4. Foundation consistency
질문: spacing, typography, radius, color, surface가 시스템처럼 반복되는가?

체크포인트:
- 카드 간 간격 규칙이 일정한가
- 타이포 스케일이 흔들리지 않는가
- radius와 border treatment가 제각각이지 않은가
- 컬러가 semantic role로 쓰이고 있는가
- 배경/표면/강조 레벨이 일관적인가

### 5. Component discipline
질문: 같은 역할의 컴포넌트가 같은 방식으로 보이고 동작하는가?

체크포인트:
- section header 패턴이 통일되어 있는가
- primary / secondary button 규칙이 안정적인가
- card variation이 필요한 수준 이상으로 늘어나지 않았는가
- badge, chip, helper text, empty state 패턴이 반복 가능한가

### 6. Content system quality
질문: 카피가 사람 말처럼 자연스러우면서도 product grammar가 유지되는가?

체크포인트:
- 라벨과 설명문이 군더더기 없이 목적을 전달하는가
- 같은 개념을 다른 단어로 반복하지 않는가
- empty / loading / error / success 메시지 톤이 통일되는가
- Explore, Home, My가 각자 다른 목소리로 떠들지 않는가

### 7. Accessibility and legibility
질문: 작은 화면, 빠른 사용, 피곤한 상황에서도 읽고 누르기 쉬운가?

체크포인트:
- 대비가 충분한가
- 탭 영역이 충분한가
- dense card에서도 정보가 뭉개지지 않는가
- 숫자/가격/수량 가독성이 좋은가
- 스크롤 중에도 현재 맥락을 잃지 않는가

### 8. Brand-product fit
질문: Cartly가 generic 쇼핑앱이 아니라 장보기 decision partner로 느껴지는가?

체크포인트:
- 홈은 실행, 탐색은 판단이라는 정체성이 살아있는가
- 절약/비교/반복구매/의사결정 가치가 보이는가
- 수익 surface가 사용자 흐름을 깨지 않고 들어가는가
- 운영 카피와 실제 앱 인상이 어긋나지 않는가

---

## 화면별 추가 평가 질문

### Home
- 지금 당장 담고, 확인하고, 저장하는 흐름이 가장 앞에 오는가?
- 스캔, 최근 스캔, 현재 카트의 관계가 헷갈리지 않는가?
- 현재 카트가 진짜 working area처럼 느껴지는가?

### Explore
- 도움말 탭이 아니라 decision inbox처럼 보이는가?
- 비교 후보가 현재 장보기 의도와 맞닿아 있는가?
- 프로모션/제휴 surface가 판단 흐름을 방해하지 않는가?

### My
- 프로필 설정 화면보다 장보기 기록 허브처럼 보이는가?
- saved carts, account state, benefits 구조가 자연스러운가?

### Login
- 진입 장벽이 낮고, 왜 로그인해야 하는지 명확한가?
- 혜택 설명이 과장되지 않고 실제 가치와 맞는가?

### Receipt compare
- 영수증 확인의 목적이 한 줄로 이해되는가?
- 총액 비교와 참고 상세가 구분되는가?
- 비구매 라인이 상품처럼 보이지 않는가?

### Current cart
- 이름, 수량, 가격, 상태가 가장 빠르게 읽히는가?
- 수정/삭제/확장 흐름이 자연스러운가?
- 긴 상품명을 다루는 방식이 시스템적으로 안정적인가?

---

## Audit 산출물 형식
각 화면 평가 때 아래 형식을 따른다.

### 화면명
- 총평:
- 점수:
  - Information hierarchy:
  - State clarity:
  - Action flow quality:
  - Foundation consistency:
  - Component discipline:
  - Content system quality:
  - Accessibility and legibility:
  - Brand-product fit:
- 잘 된 점 3개
- 문제 3개
- 바로 고칠 것
- 나중에 시스템으로 고칠 것

---

## 우선순위 규칙
문제를 찾았다고 다 바로 고치지 않는다.
우선순위는 아래 순서로 잡는다.

1. 상태 오해를 만드는 문제
2. 핵심 행동을 막는 문제
3. 정보 위계를 흐리는 문제
4. 반복적으로 신뢰를 깎는 카피/컴포넌트 불일치
5. 마지막에 시각 polish

---

## 다음 단계
1. 이 기준서로 Cartly 주요 화면 audit 수행
2. 화면별 점수와 문제 목록 정리
3. 즉시 수정 5개와 시스템 개선 5개로 나눔
4. 그다음 실제 구현 범위를 합의하고 반영
