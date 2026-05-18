# 2026-05-18 Public Site Proposal Checkpoint

## Scope of this pass

Focused on the public/business web at `scripts/app_public_proxy.mjs` and `scripts/public-site/site.css`, with a small app-side branding fallback fix to explain the real-device header-logo issue the user surfaced.

## What changed

### Public site / business web
- Reworked the landing into a more proposal-style structure instead of a thin support page.
- Tightened the top hero into a 2-card opening section with denser left-side content.
- Replaced the earlier mixed/misaligned screenshot treatment with a single main preview plus clickable feature navigation.
- Added richer feature coverage in the preview switcher:
  - 상품 스캔
  - 현재 카트
  - 저장한 장보기 기록
  - 대체안 다시 보기
  - 내 정보와 가족공유
  - 로그인과 회원 시작
- Updated footer to a one-line style using wordmark + app version + support/proposal links.
- Replaced the fake scan illustration path with the user-provided real scan screenshot (`scan-real-v2.jpg`).

### Runtime/admin copy alignment
- Updated the public-site default/fallback copy in:
  - `backend/app/services/app_copy_service.py`
  - `admin-web/lib/mock.ts`
- Key copy direction now uses the shorter proposal-facing hero title:
  - `장보기 기록과 대체안`
- Primary CTA now aligns to feature browsing:
  - `기능 보기`

### App-side branding diagnosis/fix
The user noticed the real app’s top header logo was missing in the scan screen screenshot. Investigation showed:
- admin branding value had been missing earlier but was restored
- current runtime `/v1/app-config` now returns:
  - `logoType: image`
  - `logoImageUrl: https://scan-api.seoa-nas.com/assets/branding/cartly_logo_vectorized.svg`
- however the app could still fall back to plain text if the remote SVG path was not rendered correctly at runtime on-device

To harden this, source was updated in:
- `lib/widgets/brand_mark.dart`
- `lib/pages/home_tab_view.dart`

Specifically:
- added bundled local SVG fallback for the Cartly wordmark asset
- increased home header title height so the image logo has enough vertical room

## Current live/runtime state

### Public web
- Live public site is refreshed and serving the new proposal-style layout.
- `상품 스캔` preview now points to the user-provided real screenshot asset.
- Footer is now one-line wordmark + version + support/proposal links.

### Real app on phone
- Server/admin branding values are now correct again.
- App source includes a safer bundled fallback for the wordmark.
- The app-side fix is **not shipped to device yet**; it needs the next iOS build/TestFlight upload.

## Files intentionally in scope for checkpoint
- `admin-web/lib/mock.ts`
- `backend/app/services/app_copy_service.py`
- `lib/pages/home_tab_view.dart`
- `lib/widgets/brand_mark.dart`
- `scripts/app_public_proxy.mjs`
- `scripts/public-site/site.css`
- `assets/images/branding/cartly_logo_vectorized.svg`
- `assets/images/public-site/login.png`
- `assets/images/public-site/my.png`
- `assets/images/public-site/scan-real-v2.jpg`

## Remaining follow-up
1. If the public-site visual direction is accepted, stop polishing there.
2. Ship a new iOS/TestFlight build so the real app uses the bundled logo fallback on-device.
3. After shipping, re-capture any public-site screenshots if the user wants the newest in-app logo state reflected again.

## Notes / excluded temp files
The repo still has unrelated temp images that were not part of this checkpoint and should stay out of the commit:
- `admin-web/.tmp-ads-center-fix.png`
- `admin-web/.tmp-my-compliance-preview.png`

There are also unused experimental scan assets from this pass that were not meant to be part of the checkpoint.
