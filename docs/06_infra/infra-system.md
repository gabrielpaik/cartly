# Cartly Infra System

Last updated: 2026-05-18
Status: canonical
Purpose: infrastructure and runtime operations reference for the current single-host Cartly deployment
Use this doc when: changing process model, public ingress, storage assumptions, or operational recovery steps

## 1. 현재 배포 형태
Cartly는 현재 Mac mini 중심의 pragmatic single-host 운영 구조다.
핵심은 아래와 같다.
- backend: localhost `127.0.0.1:8011`
- admin-web: localhost `127.0.0.1:3000`
- app public proxy: localhost `127.0.0.1:3100`
- storage/OCR artifacts: `/Volumes/AI/Cartly`
- public ingress: Cloudflare Tunnel

## 2. 서비스 분리

### backend
- FastAPI
- login-session context에서 실행
- NAS write permission 때문에 direct launchd background 실행 금지

### worker
- login-session context에서 supervisor가 같이 관리
- queued scan job을 지속적으로 처리

### admin-web
- Next.js production build
- LaunchAgent `com.cartly.admin-web`

### app public proxy
- public app-safe route만 backend로 전달
- marketing/privacy/support page도 함께 제공
- LaunchAgent: `com.cartly.app-public-proxy`

## 3. 왜 backend를 login-session에서 돌리는가
직접 launchd background로 띄운 backend는 `/Volumes/AI/Cartly` 쓰기에서 `PermissionError`가 날 수 있다.
반면 user login session의 Terminal context에서는 정상 쓰기 가능하다.

따라서 현재 운영 원칙:
- backend/worker는 login-session supervisor 구조 유지
- admin/public proxy만 별도 서비스로 다룸

## 4. public ingress

### app/public
- domain: `scan-api.seoa-nas.com`
- path owner: app public proxy
- 노출 대상: app-safe APIs + public pages

### admin
- domain: `cartly-admin.seoa-nas.com`
- path owner: admin-web
- backend `/admin/*`는 여전히 token 보호

## 5. local env / 주요 파일
- admin env: `~/Library/Application Support/Cartly/admin.env`
- admin LaunchAgent: `~/Library/LaunchAgents/com.cartly.admin-web.plist`
- app public proxy LaunchAgent: `~/Library/LaunchAgents/com.cartly.app-public-proxy.plist`
- runtime assets root: `~/Library/Application Support/Cartly/assets/`
- branding assets: `~/Library/Application Support/Cartly/assets/branding/`
- ads assets: `~/Library/Application Support/Cartly/assets/ads/`
- backend entrypoint: `/Users/sdpaik/dev/cartly/scripts/Cartly Backend.command`
- runtime refresh entrypoint: `/Users/sdpaik/dev/cartly/scripts/Cartly Runtime Refresh.command`
- worker entrypoint: `/Users/sdpaik/dev/cartly/scripts/Cartly Worker.command`
- login-session backend runner: `/Users/sdpaik/dev/cartly/scripts/run-backend-login-session.sh`
- runtime supervisor runner: `/Users/sdpaik/dev/cartly/scripts/run-runtime-supervisor-login-session.sh`
- backend one-shot runner: `/Users/sdpaik/dev/cartly/scripts/run-backend-once-login-session.sh`
- NAS mount helper: `/Users/sdpaik/dev/cartly/scripts/ensure-nas-mount.sh`
- current local Python baseline: Homebrew `python@3.12` via `/Users/sdpaik/dev/cartly/backend/.venv`

주요 env 예시:
- `ADMIN_TOKEN`
- `API_BASE_URL`
- `CARTLY_API_BASE`
- `APP_PUBLIC_PROXY_BACKEND_BASE`
- `APP_PUBLIC_PROXY_PORT`

## 6. canonical 운영 명령

### runtime refresh
```bash
/Users/sdpaik/dev/cartly/scripts/Cartly\ Runtime\ Refresh.command
```

역할:
- admin-web rebuild
- backend/admin/public runtime refresh
- health / app-config / critical paths smoke check

### backend 복구
```bash
/Users/sdpaik/dev/cartly/scripts/Cartly\ Backend.command
```

### preview 포함 refresh
```bash
/Users/sdpaik/dev/cartly/scripts/Cartly\ Runtime\ Refresh.command --with-preview
```

## 7. health / smoke 기준

### backend
- `curl http://127.0.0.1:8011/health`
- `storageWritable: true` 확인

### admin
- `/login`, `/overview` 로딩 확인
- stale code 증상 있으면 full refresh

### public app path
- `/health`
- `/v1/app-config`
- guest auth
- scan job create
- receipt route
- household current cart route
- push status/device registration route

## 8. 운영상 중요한 사고 포인트

### stale process
- admin 소스 바뀌었는데 옛 코드가 계속 떠 있는 경우가 있음
- `EADDRINUSE`나 port 점유 꼬임이 발생할 수 있음
- 이때 부분 수정보다 full runtime refresh를 우선

### route allowlist
- public proxy는 허용 route만 전달한다.
- `/v1/households/*` 누락 같은 allowlist 문제는 앱 기능을 바로 깨뜨린다.

### NAS mount
- `/Volumes/AI`가 안 붙으면 OCR/영수증 파이프라인이 깨진다.
- login session 초기화 시 mount 복구 보조 스크립트를 거친다.

## 9. 로그/관찰 포인트
- backend login-session log: `~/Library/Logs/Cartly/backend-login-session.log`
- runtime supervisor log: `~/Library/Logs/Cartly/runtime-supervisor.log`
- admin-web log: `~/Library/Logs/Cartly/admin-web.log`
- runtime refresh log: `~/Library/Logs/Cartly/runtime-refresh.log`

## 10. 운영 복구 기본 순서
1. `curl http://127.0.0.1:8011/health` 확인
2. `storageWritable` 확인
3. 필요 시 `Cartly Runtime Refresh.command` 실행
4. 그래도 backend가 없으면 `Cartly Backend.command` 재실행
5. public app path와 admin path를 각각 smoke check

## 11. 확장 시 지켜야 할 원칙
- backend public exposure 금지
- admin과 app public ingress 분리 유지
- DB를 state source로 유지
- NAS는 runtime/storage infra로 유지
- 실제 운영 검증 없이 “구조상 맞다”로 판단하지 않기

## Related notes
- [[03_backend/backend-architecture]]
- [[04_admin/admin-system]]
- [[05_web/web-service]]
- [[07_release/release-management]]
