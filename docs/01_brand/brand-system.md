# Cartly Brand System

Last updated: 2026-05-18
Status: canonical
Purpose: brand reference for product, web, and AI-assisted design/build work
Use this doc when: defining Cartly visual identity, naming, logo behavior, or cross-surface brand rules

## 1. Brand intent
Cartly should feel like a **calm, trustworthy grocery decision partner**.
It is not a coupon app, not a flashy commerce feed, and not a warm-pink lifestyle brand.

Core impression:
- practical
- structured
- trustworthy
- light but not playful
- warm enough to feel human, but never cute or sugary

## 2. Naming system
- Primary English name: `Cartly`
- Primary Korean name: `카트리`
- Accepted typo/variant to recognize: `카틀리`
- Internal legacy codename: `WIMC`

Rules:
- User-facing surfaces should prefer `Cartly` or `카트리`.
- `WIMC` stays only in legacy technical contexts such as bundle ids, old paths, or compatibility notes.

## 3. Brand personality
If an AI agent or designer needs a shorthand, use this:

> Cartly is more Muji-notebook than supermarket flyer.

That means:
- clean structure over decorative excitement
- information clarity over emotional excess
- confidence over cuteness
- utility over promo noise

## 4. What Cartly is not
Do not style Cartly like:
- a discount-event banner site
- a pink beauty/lifestyle app
- a generic e-commerce checkout app
- a fintech dashboard with cold enterprise severity
- an AI toy product with neon/futuristic gimmicks

## 5. Logo system

### Semantic roles
- **App icon / symbol**: circular mark, compact identifier
- **Wordmark**: `cartly_logo_vectorized.svg`

### Hard rules
- The wordmark is **left-aligned by default**.
- Do not center the wordmark in a wide banner-like block.
- Do not crop the wordmark to force a lockup.
- Do not over-enlarge the logo just because there is empty space.
- If the header already carries the brand lockup, the hero should not repeat a giant logo block.

### Asset references
- Runtime logo URL: `https://scan-api.seoa-nas.com/assets/branding/cartly_logo_vectorized.svg`
- Bundled fallback: `assets/images/branding/cartly_logo_vectorized.svg`
- Local deployed asset: `~/Library/Application Support/Cartly/assets/branding/cartly_logo_vectorized.svg`
- Native iOS app icon source: `ios/Runner/Assets.xcassets/AppIcon.appiconset/*`
- Native Android launcher source: `android/app/src/main/res/mipmap-*/ic_launcher.png`
- Current splash fallback image: `assets/images/intro.png`

## 6. Runtime branding contract
Branding is runtime-driven first, not hardcoded first.
Primary source:
- `/v1/app-config` → `branding`

Key fields:
- `logoType`
- `logoText`
- `logoImageUrl`
- `splashImageUrl`
- `loginHeroImageUrl`
- `tabs.home`
- `tabs.help`
- `tabs.my`

Related admin-managed asset surfaces:
- logo upload
- splash upload
- login hero upload

Current runtime-aligned values:
- `logoType: image`
- `logoText: Cartly`
- `logoImageUrl: https://scan-api.seoa-nas.com/assets/branding/cartly_logo_vectorized.svg`
- `splashImageUrl: https://scan-api.seoa-nas.com/assets/branding/cartly_splash_default.png`
- `loginHeroImageUrl: null`

Operational rules:
- Admin editability and real screen consumption are different concerns.
- Every new branded surface must explicitly consume runtime branding.
- Known remote SVG failures should fall back to the bundled asset, not plain text if avoidable.

## 7. Color direction
This is a direction spec, not a frozen token sheet.

### Primary feel
- paper-like off-white base
- neutral ink text
- restrained red for active emphasis
- no heavy gradients by default

### Current anchors
- app base white: `#FDFCF8`
- selected/active emphasis: Cartly red

### Avoid
- pink or warm-pink primary identity
- candy, blush, peach-heavy accents
- saturated sale-banner red overload
- oversized dark contrast blocks everywhere

## 8. Typography and tone feel
Cartly typography should feel:
- readable first
- structured second
- branded third

Meaning:
- do not solve hierarchy by making everything extra bold
- use spacing, scale, and surface contrast before weight inflation
- titles should feel composed, not loud
- body copy should be short, human, and operationally clear

## 9. Splash and launch policy
- Flutter splash and native iOS launch are separate layers.
- The first white launch screen is controlled by iOS `LaunchScreen`.
- If splash artwork changes again, use a **user-provided prepared image** as the source of truth.
- Do not generate speculative composite splash artwork.
- Keep `splashImageUrl` pointed at a valid default asset, not `null`.

## 10. Brand behavior by surface

### App
- brand mark should feel integrated into the product shell
- logo presence should support navigation stability, not dominate the page

### Public web
- brand lockup should be compact and proposal-grade
- trust and information hierarchy matter more than decorative branding

### Store presence
- Korean display name should remain `카트리`
- keyword strategy can include English and typo variants, but the visible brand should stay clean

## 11. Do / Don’t

### Do
- keep the brand compact
- keep layouts airy and structured
- prefer real screenshots to invented marketing scenes
- use the logo as a trust signal, not a decoration contest

### Don’t
- make the logo the largest thing on the screen by default
- reintroduce pink customer UI theming
- let fallback states degrade to ugly generic text when an asset fallback exists
- build brand expression from “sale” aesthetics

## 12. Implementation references
- `lib/widgets/brand_mark.dart`
- `lib/pages/home_tab_view.dart`
- `backend/app/services/branding_service.py`
- `backend/app/services/app_config_service.py`
- `backend/app/services/app_copy_service.py`
- `scripts/app_public_proxy.mjs`
- `assets/images/branding/cartly_logo_vectorized.svg`

## 13. When to update this doc
Update when any of these change:
- brand naming
- logo semantics or asset source
- color identity direction
- splash/launch policy
- cross-surface brand behavior rules

## Related notes
- [[02_product/app-design]]
- [[05_web/web-brand-design]]
- [[07_release/release-management]]
