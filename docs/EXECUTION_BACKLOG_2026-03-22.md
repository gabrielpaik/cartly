# Cartly Execution Backlog — 2026-03-22

Owner: CEO(승대)
Working repo: `/Users/sdpaik/dev/cartly`

## Principle
- OCR 품질이 아직 낮다는 점을 전제로 설계한다.
- NAS(`/Volumes/AI/Cartly`)는 AI 처리/저장 인프라로 활용하고, 제품 상태의 source of truth는 backend + DB로 둔다.
- 홈 → 스캔 → 결과보정 → 현재카트 → 저장 → 히스토리 루프를 최우선으로 본다.
- 광고는 핵심 루프를 해치지 않는 수준에서만 검토한다.

---

## Track A — CTO / OCR + NAS + AI
### Goal
낮은 OCR 품질을 운영 가능한 수준으로 끌어올릴 수 있는 기술 구조를 확정한다.

### TODO
- [ ] 스캔 파이프라인 현재 구조 문서화 (app → backend → worker → NAS → result)
- [ ] scan_job 상태 전이 명확화 (`queued`, `processing`, `done`, `failed`)
- [ ] OCR 품질 측정 기준 정의
  - [ ] item name 정확도
  - [ ] price 정확도
  - [ ] confidence threshold
  - [ ] 재촬영/수정 비율
- [ ] 사용자 수정 결과를 학습/평가 데이터로 적재하는 feedback loop 정리
- [ ] `/Volumes/AI/Cartly` 내 운영 폴더 역할 고정
  - [ ] `input`
  - [ ] `processing`
  - [ ] `output`
  - [ ] `failed`
  - [ ] `archive`
  - [ ] `logs`
  - [ ] `config`
- [ ] 모델/프롬프트/파서 버전 관리 방식 정의
- [ ] 실패 케이스 로깅 규격 정의
- [ ] mock/remote 경로 정리 계획 수립
- [ ] backend를 cart/auth/scan state의 source of truth로 고정

### Immediate execution
- [ ] 기술 구조 진단 문서 1차 작성
- [ ] OCR 품질 진단용 샘플/로그 수집 규격 정의
- [ ] scan feedback endpoint 사용 흐름 점검

---

## Track B — CDO / UX/UI
### Goal
Cartly를 기능 데모가 아니라 제품 경험으로 바꾼다.

### TODO
- [ ] 홈 정보구조 재설계
- [ ] 스캔 결과 확인/보정 화면 UX 개선
- [ ] 현재 카트 vs 저장 카트 역할 분리
- [ ] 저장 완료 후 다음 액션 설계
- [ ] 히스토리 접근성을 drawer 중심 구조에서 분리 검토
- [ ] 사용자 문구에서 내부 개발 언어 제거
- [ ] OCR 신뢰도 낮을 때 UX 처리 규칙 정의

### Immediate execution
- [ ] 핵심 사용자 여정(홈→스캔→보정→저장→히스토리) 1차 플로우 작성
- [ ] 홈/결과보정/저장완료/히스토리 화면 우선순위 확정

---

## Track C — CMO / 포지셔닝 + 시장검증
### Goal
Cartly를 단순 OCR 앱이 아니라 반복 사용되는 쇼핑 유틸리티로 포지셔닝한다.

### TODO
- [ ] Cartly 한 줄 정의 3안 작성
- [ ] 직접 경쟁 / 인접 경쟁 / 플랫폼 위협 구분
- [ ] 첫 고객 세그먼트 정의
- [ ] OCR 품질이 최고가 아니어도 설 수 있는 메시지 정리
- [ ] 장보기 기록/재사용/가격 기억 가치 검증 질문지 만들기
- [ ] 한국 시장용 로그인/가치 메시지 가설 정리

### Immediate execution
- [ ] 첫 메시지 3개 작성
- [ ] 비교 대상 서비스 목록 정리
- [ ] GTM 리스크 1차 정리

---

## Track D — CFO / 수익화 + 측정
### Goal
수익화 인프라는 조기에 설계하되, 제품 경험을 해치지 않도록 통제한다.

### TODO
- [ ] MVP 광고 정책 정의
- [ ] 광고 노출 가능 영역/금지 영역 구분
- [ ] ad slot 서버 제어 원칙 정리
- [ ] ad impression / click event schema 점검
- [ ] retention 우선 KPI 정의
- [ ] 장기 수익모델(광고/제휴/B2B) 시나리오 초안 작성

### Immediate execution
- [ ] 광고 허용 화면 후보: 저장 완료 / 히스토리
- [ ] 광고 금지 화면 후보: 스캔 / 보정 / 현재카트 편집
- [ ] MVP KPI 초안: 저장률, 재방문율, 카트 재사용률

---

## Parallel first pass (next 24h)
- [ ] CTO: 현재 scan 구조/리스크 1차 진단
- [ ] CDO: 핵심 플로우 재설계 초안
- [ ] CMO: 포지셔닝 문장 3개 + 경쟁 맵
- [ ] CFO: 광고 정책 초안 + KPI 프레임

## CEO checkpoints
- [ ] Cartly를 어떤 문장으로 정의할지 선택
- [ ] 광고 허용 수준 결정
- [ ] OCR 품질 개선을 위한 우선 투자 범위 결정
- [ ] 첫 출시 타깃(내부 검증 / 소규모 사용자 / 외부 공개) 결정
