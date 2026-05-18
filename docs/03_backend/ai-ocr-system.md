# Cartly AI OCR System

Last updated: 2026-05-18
Status: canonical
Purpose: OCR and receipt-analysis pipeline contract from upload to structured result
Use this doc when: changing scan/receipt processing, storage artifacts, or quality feedback loops

## 1. 목적
Cartly의 AI/OCR 시스템은 단순 텍스트 인식이 아니라, **장보기와 영수증을 제품 흐름에 쓸 수 있는 구조화 데이터로 바꾸는 파이프라인**이다.

현재는 두 축이 있다.
- 상품/가격표 스캔
- 영수증 분석

## 2. 전체 구조
1. 앱이 이미지 업로드
2. backend가 job 또는 receipt record 생성
3. worker/OpenClaw runner가 분석 수행
4. 구조화 결과를 DB + JSON artifact로 저장
5. 앱/운영이 결과를 조회/검토/활용

## 3. 스토리지 역할
storage root:
- `/Volumes/AI/Cartly`

주요 버킷:
- `input/` 원본 업로드
- `output/` 성공 결과 JSON
- `archive/` 완료 원본 보관
- `failed/` 실패 결과 JSON
- `receipts/analysis/` 영수증 분석 결과
- `receipts/failed/` 영수증 실패 기록

원칙:
- NAS는 파일/아티팩트 저장소다.
- 상태 판단은 DB와 API가 한다.

## 4. 상품 스캔 파이프라인

### 앱 흐름
- 이미지 업로드
- `POST /v1/scan/jobs`
- job polling
- result fetch
- 사용자 검토 후 feedback 저장

### backend/job 흐름
- `scan_jobs.status=queued`
- worker가 oldest queued job 획득
- `processing` 전환
- OpenClaw scan runner 실행
- category enrichment 수행
- 결과 JSON 저장
- source image archive
- job `done` 또는 `failed` 마감

### 결과 구조 핵심
- `name`
- `price`
- `sku`
- `confidence`
- `source`
- `rawText`
- `meta.categoryMeta`

## 5. 영수증 파이프라인

### 제품 목적
영수증은 고객에게 “비교 검토용”이 아니라 **실제 구매 정답**에 가깝다.
따라서 결과는 saved cart 정리와 purchase-complete 흐름에 사용된다.

### 핵심 처리
- OpenClaw receipt runner가 line item 구조를 생성
- item / subtotal / tax / discount / payment category를 구분
- merchant, purchasedAt, totalAmount, totalDiscountAmount 등 요약치 계산
- receipt artifact JSON 저장

### 후속 활용
- receipt apply
- cart title 갱신
- purchasedAt 기반 날짜 노출
- 할인 메타데이터 반영

## 6. 품질 보정 레이어

### scan feedback
사용자가 아래를 남길 수 있다.
- accepted
- corrected name/price

이 데이터는 운영 품질 회고에 중요하다.

### category enrichment
스캔 결과에 대해 category meta를 추가한다.
- 식품/생활/디지털 등 카테고리 후보
- `기타` 남용을 줄이는 방향
- 실제 상품명 evidence 기반 보정

### category override
사용자 수동 카테고리 수정은 별도 override로 유지한다.

## 7. 실패 처리

### 스캔
실패 시:
- job status = `failed`
- `error_code`, `error_message` 저장
- failed JSON artifact 저장
- `scan_failure_logs` 기록

대표 에러 계열:
- `INVALID_IMAGE_PATH`
- `IMAGE_NOT_FOUND`
- `OPENCLAW_*`
- `WORKER_FAILED`

### 영수증
실패 시:
- receipt status = `failed`
- error message 저장
- failed artifact 저장

## 8. 운영상 중요한 판단
- “인식 품질 문제”로 보이더라도 먼저 worker가 실제로 돌고 있는지 확인한다.
- `/v1/scan` 요청이 backend에 실제 도달했는지 먼저 본다.
- 구조화된 agent 실패가 runner에서 잘 분류되는지 본다.

## 9. 실제 운영 체크포인트
- `/health`에서 storage writable 확인
- queued job이 worker에 의해 줄어드는지 확인
- `output/` 또는 `failed/`에 artifact가 생기는지 확인
- admin scan ops에서 feedback/failure가 보이는지 확인

## 10. 현재 한계
- fully online streaming inference는 아님
- 영수증 item matching과 cart replacement는 아직 더 정교해질 수 있음
- OCR 품질 향상에는 계속 실데이터 피드백이 필요

## 11. 관련 파일
- `backend/app/services/worker_service.py`
- `backend/app/services/receipt_service.py`
- `backend/app/services/scan_category_service.py`
- `backend/app/services/openclaw_scan_runner.py`
- `backend/app/services/openclaw_receipt_runner.py`
- `backend/app/routers/scan.py`

## Related notes
- [[02_product/app-product]]
- [[03_backend/backend-architecture]]
- [[03_backend/database-schema]]
