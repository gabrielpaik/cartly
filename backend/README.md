# Cartly backend

Cartly backend for app runtime, admin runtime, and scan processing.

## Current runtime shape
- FastAPI API server
- PostgreSQL via SQLAlchemy
- NAS-backed scan storage under `storage_root`
- Background scan worker (`worker.py` / `worker_daemon.py`)
- App runtime config at `GET /v1/app-config`

## Scan pipeline
App flow is intentionally stable:
1. app uploads image to `POST /v1/scan/jobs`
2. backend stores source image and creates a queued scan job
3. worker processes queued job
4. app polls `GET /v1/scan/jobs/{id}`
5. app fetches result from `GET /v1/scan/jobs/{id}/result`
6. app sends correction/acceptance feedback to `POST /v1/scan/jobs/{id}/feedback`

## Scan engines
Worker execution is now pluggable through environment variables.

### 1) Tesseract mode (default)
```env
SCAN_ENGINE=tesseract
```
Uses local OCR + label parser inside `worker_service.py`.

### 2) OpenClaw mode
```env
SCAN_ENGINE=openclaw
OPENCLAW_SCAN_COMMAND=python /Users/sdpaik/dev/wimc/scripts/openclaw_scan_runner.py --job-id {job_id} --image-path {image_path}
OPENCLAW_SCAN_AGENT_ID=<configured-openclaw-agent-id>
OPENCLAW_SCAN_TIMEOUT_SECONDS=90
OPENCLAW_SCAN_FALLBACK_TO_TESSERACT=true
```

### 3) Hybrid mode
```env
SCAN_ENGINE=hybrid
OPENCLAW_SCAN_COMMAND=python /Users/sdpaik/dev/wimc/scripts/openclaw_scan_runner.py --job-id {job_id} --image-path {image_path}
OPENCLAW_SCAN_AGENT_ID=<configured-openclaw-agent-id>
```
Hybrid tries OpenClaw first and falls back to Tesseract if OpenClaw fails.

## OpenClaw runner contract
`OPENCLAW_SCAN_COMMAND` must print JSON to stdout.

A starter runner is included at:
- `scripts/openclaw_scan_runner.py`

That runner currently calls:
- `openclaw agent --agent <OPENCLAW_SCAN_AGENT_ID> --local --json`

It asks the agent to read the local image path directly and return strict JSON.

### Success payload
```json
{
  "ok": true,
  "result": {
    "name": "서울우유 1L",
    "price": 2980,
    "sku": "1234567",
    "confidence": 0.94,
    "source": "openclaw-skill",
    "rawText": "서울우유 1L 2,980원"
  },
  "meta": {
    "runner": "openclaw",
    "model": "gpt-5.4",
    "workflow": "scan-label-v1"
  }
}
```

### Failure payload
```json
{
  "ok": false,
  "error": {
    "code": "LOW_CONFIDENCE",
    "message": "상품명/가격을 충분히 확정하지 못했어",
    "details": {
      "reason": "text too noisy"
    }
  }
}
```

## Receipt analysis pipeline
Receipt analysis does not reuse the shelf-label parser itself. Instead, it uses the same operating model with a separate receipt-analysis path:
- receipt image is stored under NAS `storage_root`
- backend calls `scripts/openclaw_receipt_runner.py`
- the runner uses `openclaw agent --local --json`
- returned receipt line items/totals are persisted so the app can show stored detail and final-total comparison against the saved cart

### Preferred receipt-analysis env
```env
OPENCLAW_RECEIPT_ANALYSIS_AGENT_ID=<configured-openclaw-agent-id>
OPENCLAW_RECEIPT_ANALYSIS_TIMEOUT_SECONDS=120
OPENCLAW_RECEIPT_ANALYSIS_COMMAND=python /Users/sdpaik/dev/wimc/scripts/openclaw_receipt_runner.py --receipt-id {receipt_id} --image-path {image_path}
```

Compatibility fallbacks still work in this order:
- `OPENCLAW_RECEIPT_AGENT_ID`
- `OPENCLAW_SCAN_AGENT_ID`

Legacy command/timeouts also still work:
- `OPENCLAW_RECEIPT_COMMAND`
- `OPENCLAW_RECEIPT_TIMEOUT_SECONDS`
- `OPENCLAW_RECEIPT_SCAN_COMMAND`
- `OPENCLAW_RECEIPT_SCAN_TIMEOUT_SECONDS`

## Notes
- Existing app API contract remains unchanged.
- Worker still writes output / archive / failed artifacts under NAS storage.
- App feedback is now connected to scan job ids so accepted/corrected outcomes can accumulate for future quality loops.
