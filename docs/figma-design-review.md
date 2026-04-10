# WIMC Figma Design Review 기준

## 목적
- 기능 개발과 분리해서 UI를 시각적으로 검토한다.
- app의 Widgetbook, admin web의 Storybook과 Figma를 1:1로 맞춘다.
- 이번 모드에서는 API/state/navigation/business logic 변경 없이 디자인 디테일만 반복 검토한다.

## 리뷰 단위
항상 아래 단위로 자른다.

1. **Screen**
   - 예: `app/home`, `app/saved`, `app/my`, `app/login`
   - 예: `admin/overview`, `admin/users`, `admin/carts`, `admin/content`

2. **Section**
   - 예: `app/item-add-section`, `app/recent-saved-card`, `admin/page-header`

3. **Component**
   - 예: `app/brand-mark`, `app/item-card`, `admin/stat-card`

## 상태 naming 규칙
Story/Use case/Figma frame 이름을 아래처럼 맞춘다.

- `screen-name / baseline`
- `screen-name / empty`
- `screen-name / filled`
- `screen-name / guest`
- `screen-name / member`
- `screen-name / loading`
- `screen-name / error`
- `screen-name / read-only-preview`

예시:
- `home / baseline`
- `saved / filled`
- `my / guest`
- `my / member`
- `overview / baseline`
- `content / baseline`

## Figma 페이지 구조
권장 구조:

- `00_cover`
- `01_review_board_app`
- `02_review_board_admin`
- `03_components_app`
- `04_components_admin`
- `05_archive`

## Frame 규칙
각 Frame에는 아래 메타를 남긴다.

- 화면 이름
- 상태 이름
- 기준 viewport
- 검토 날짜
- 수정 owner
- 구현 경로
  - app: Widgetbook path
  - admin: Storybook story path

## Viewport 기준
기본 검토 viewport:

### App
- iPhone 13
- Samsung Galaxy S20
- Desktop/macOS fallback

### Admin
- Desktop wide
- Tablet width
- Mobile narrow width

## 한 번에 보는 체크리스트
디자인 리뷰는 아래 순서로 본다.

1. 레이아웃
   - 상하 여백
   - 좌우 패딩
   - 카드 간격
   - sticky/fixed bar 높이

2. 타이포
   - 제목/본문 위계
   - line-height
   - weight 밸런스
   - 한글 가독성

3. 컬러/강조
   - primary red 사용 위치
   - 강조 정보와 보조 정보 대비
   - 경고/실패/성공 톤 분리

4. 정보 밀도
   - 한 화면에서 너무 빽빽하지 않은지
   - 카드 한 개가 너무 많은 정보를 먹지 않는지
   - CTA 우선순위가 명확한지

5. 상태 일관성
   - empty / filled / guest / member 간 톤 유지
   - admin 전 페이지의 header / card / table 패턴 일관성

## 수정 기록 방식
Figma 코멘트는 아래 형식으로 남긴다.

- `Issue:` 무엇이 어색한지
- `Why:` 왜 문제인지
- `Change:` 어떻게 바꿀지
- `Scope:` screen / section / component
- `Priority:` P1 / P2 / P3

예시:
- `Issue: Saved 카드 상하 간격이 좁다`
- `Why: 목록이 붙어 보여서 스캔이 어렵다`
- `Change: 카드 margin-bottom 12 -> 16 검토`
- `Scope: section`
- `Priority: P2`

## 작업 원칙
- 기능 변경과 UI 검토를 섞지 않는다.
- Storybook/Widgetbook에서 먼저 본다.
- Figma에서 방향을 합의한 뒤 실제 화면에 최소 수정한다.
- 한 번에 큰 개편보다 작은 시각 수정 단위로 간다.

## 승대가 준비할 것
1. Figma 파일/페이지 하나를 이 리뷰 기준으로 정리
2. 우선 검토할 화면 우선순위 지정
   - app: home / saved / my / login / cart-detail
   - admin: overview / users / carts / content / ads / config
3. 브랜드 자산이 있으면 준비
   - 로고 SVG/PNG
   - 스플래시 이미지
4. 이번 라운드에 꼭 볼 상태 지정
   - empty / filled / guest / member / loading 중 무엇부터 볼지
5. 최종 viewport 우선순위 지정
   - 모바일 우선인지, 데스크톱 우선인지
