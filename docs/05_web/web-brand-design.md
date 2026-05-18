# Cartly Web Brand Design

Last updated: 2026-05-18
Status: canonical
Purpose: visual direction for public, proposal, and marketing-facing Cartly web surfaces
Use this doc when: refining public-site visuals, hero/layout behavior, screenshot usage, or proposal-grade web presentation

## 1. Design intent
The Cartly web presence should feel like a **credible product proposal page**, not a temporary beta landing page and not a consumer-promo microsite.

If an AI agent needs one line:

> Design the site like a compact product proposal with real product evidence.

## 2. Desired impression
- trustworthy
- structured
- modern
- concise
- screenshot-backed

Not:
- playful startup fluff
- pink lifestyle brand
- coupon/promo flyer
- overproduced SaaS gradient spectacle

## 3. Brand lockup rules

### Header
- circular app icon = app symbol
- SVG wordmark = wordmark
- keep the lockup compact
- avoid cramped icon treatment
- avoid cropped wordmark treatment

### Hero
- the hero should lead with product meaning, not oversized branding
- if the header already establishes brand, the hero should not repeat a giant icon/logo composition
- title and subtitle should feel balanced, not shrunken into timidity or blown up into marketing noise

### Footer
- one-line footer direction
- wordmark + app version + support/proposal links
- no footer app icon

## 4. Layout grammar

### Upper section
- top one or two zones may use card treatment
- this is the most “landing-like” part of the page

### Lower sections
- should become flatter and more proposal-like
- rely on structure and comparison, not stacked decorative cards

### Information density
- density is good when it improves credibility
- duplicated copy is bad and should be aggressively reduced

## 5. Screenshot rules
- use real app screenshots
- the `상품 스캔` preview must be a real scan screenshot
- avoid fake camera art or invented mobile mocks
- screenshot sizes should feel coherent, not mismatched across devices or panels
- preview navigation should connect clearly to the screenshot being shown

## 6. Copy tone
- short
- factual
- proposal-ready
- no beta excuse language unless strategically necessary
- prefer concrete version/status language over vague “coming soon” posture

## 7. Current accepted visual direction
- cooler slate / blue-neutral base is acceptable
- remove amateur warm/pink feel
- compact brand lockup in header
- app version badge is a useful credibility detail
- iPad is not a hero visual; it can be mentioned lightly if needed

## 8. Feature preview behavior
The feature list should behave like a real product navigator.
That means:
- comprehensive enough to explain the product
- clickable / switchable preview logic
- each label maps cleanly to a real screenshot or state

Current useful categories include:
- 상품 스캔
- 현재 카트
- 저장한 장보기 기록
- 대체안 다시 보기
- 내 정보와 가족공유
- 로그인과 회원 시작

## 9. Do / Don’t

### Do
- make the site feel proposal-grade
- use real product captures as proof
- compress the brand and let the product story lead
- prefer trust, structure, and persuasion over visual gimmicks

### Don’t
- reintroduce pink as the main emotional layer
- oversize logo, title, or subtitle without reason
- use fake screenshots
- repeat the same message in multiple sections
- let the hero feel like a generic startup template

## 10. Key assets and references
- wordmark fallback: `/assets/branding/cartly_logo_vectorized.svg`
- app icon route: `/site-media/app-icon.png`
- current scan preview: `/site-media/scan-real-v2.jpg`
- public-site assets: `assets/images/public-site/*`
- implementation files: `scripts/app_public_proxy.mjs`, `scripts/public-site/site.css`

## 11. When to update this doc
Update when these change:
- hero/header/footer brand behavior
- screenshot policy
- proposal-vs-landing positioning
- main visual tone direction

## Related notes
- [[01_brand/brand-system]]
- [[02_product/app-design]]
- [[05_web/web-marketing-pages]]
