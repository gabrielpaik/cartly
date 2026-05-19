# Cartly Web Service

Last updated: 2026-05-18
Status: canonical
Purpose: public web and app-public-proxy service contract
Use this doc when: changing public routes, support/privacy surfaces, or web/runtime serving behavior

## 1. 역할
Cartly web은 단순 홍보 페이지가 아니다.
현재 web service는 아래 3가지를 동시에 수행한다.
1. public product/proposal page
2. privacy / support 운영 표면
3. app review / store metadata에서 참조하는 공식 URL surface

## 2. 현재 공개 URL
- root: `https://scan-api.seoa-nas.com/`
- privacy: `https://scan-api.seoa-nas.com/privacy`
- support: `https://scan-api.seoa-nas.com/support`

## 3. 서빙 구조
- public hostname `scan-api.seoa-nas.com`
- Cloudflare Tunnel
- `app_public_proxy` on `127.0.0.1:3100`
- proxy가 app-safe API route와 public pages를 함께 제공

## 4. current route model

### public pages
- `/`
- `/partners` (proposal/landing alias)
- `/privacy`
- `/support`

### public app-safe API
- `/v1/auth/*`
- `/v1/scan/*`
- `/v1/carts/*`
- `/v1/receipts/*`
- `/v1/events/*`
- `/v1/ads/*`
- `/v1/push/*`
- `/v1/app-config`
- `/v1/households/*`
- `/assets/branding/*`
- `/assets/ads/*`
- `/health`

### explicitly not public here
- `/admin/*`

## 5. 현재 제품/운영 의미
이 웹은 marketing-only surface가 아니다.
다음 목적 때문에 운영상 중요하다.
- App Store privacy/support URL
- 제품 제안서/소개 링크
- 실제 앱 스크린샷 기반 신뢰 확보
- public runtime branding 자산 노출

## 6. runtime/content 구조
public site는 두 레이어가 있다.
1. `scripts/app_public_proxy.mjs`의 fallback/render logic
2. backend/admin content settings에서 내려오는 live content

원칙:
- 소스만 바꾸면 끝나지 않는다.
- live DB content가 override할 수 있으므로 source + runtime 값을 같이 봐야 한다.

## 7. 현재 노출 정보
- 앱 버전 라벨
- 짧은 제품 소개
- 실제 앱 스크린샷
- support email
- business proposal email
- privacy/support 진입점
- public app config 및 branding asset 접근 경로

## 8. 지원/연락처 규칙
- customer support: `cartly.support@gmail.com`
- business proposal: `gabriel.paik@gmail.com`
- support phone은 현재 공개 운영 정보에 두지 않는다.

## 9. app review와의 관계
- privacy URL은 App Store Connect에 연결됨
- support URL은 App Store Connect에 연결됨
- guest mode, location usage, account deletion 등 설명과 충돌하지 않게 유지해야 함

## 10. 운영 규칙
- public page copy를 바꾸면 live runtime까지 확인한다.
- scan screenshot 같은 대표 자산은 fabricated mock이 아니라 실제 앱 캡처를 쓴다.
- admin/content 값이 fallback을 덮고 있는지 확인한다.
- proxy allowlist 누락 시 앱 기능이 깨질 수 있다. household route 누락 경험이 이미 있었다.

## 11. 관련 파일
- `scripts/app_public_proxy.mjs`
- `scripts/public-site/site.css`
- `backend/app/services/app_copy_service.py`
- `admin-web/lib/mock.ts`
- `assets/images/public-site/*`

## Related notes
- [[05_web/web-brand-design]]
- [[05_web/web-marketing-pages]]
- [[06_infra/infra-system]]
- [[07_release/release-management]]
