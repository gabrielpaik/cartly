# Cartly NAS architecture (MVP)

## NAS root

- Mount: `/Volumes/AI`
- App workspace: `/Volumes/AI/Cartly`

Use a dedicated Cartly subtree instead of mixing with `/Volumes/AI/input` or `/Volumes/AI/output` directly.

## Folder layout

```text
/Volumes/AI/Cartly/
  config/
  input/
  processing/
  output/
  failed/
  archive/
  logs/
  temp/
```

## Meaning

- `config/`
  - app/server config, model switches, thresholds
- `input/`
  - newly uploaded images waiting to be processed
- `processing/`
  - files currently claimed by a worker
- `output/`
  - final result json files keyed by job id
- `failed/`
  - failed images / failed json records
- `archive/`
  - optional long-term retention for completed images/results
- `logs/`
  - worker and API logs
- `temp/`
  - transient temp files only

## API shape (MVP)

### POST /scan/jobs
Upload one image and create a job.

Response:
```json
{
  "jobId": "job_20260320_001",
  "status": "queued"
}
```

### GET /scan/jobs/:id
Check job status.

Response:
```json
{
  "jobId": "job_20260320_001",
  "status": "processing",
  "errorMessage": null
}
```

### GET /scan/jobs/:id/result
Get final recognized result.

Response:
```json
{
  "jobId": "job_20260320_001",
  "status": "done",
  "result": {
    "name": "커클랜드 키친타올",
    "price": 18990,
    "sku": "123456",
    "confidence": 0.82,
    "source": "nas-ai",
    "rawText": "..."
  }
}
```

## App integration principle

- The app must not know SMB folder paths.
- The app talks only to an API layer.
- NAS path handling stays on the server side.
- Keep local OCR only as optional fallback/dev mode.

## Implementation order

1. Add `RemoteScanRepository` in app
2. Add lightweight NAS API service
3. Make app switchable between mock and remote repositories
4. Add auth/session after scan path is stable
