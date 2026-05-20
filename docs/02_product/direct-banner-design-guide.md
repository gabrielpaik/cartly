# Cartly Direct Banner Design Guide

Last updated: 2026-05-20
Status: first practical draft
Purpose: define direct-banner creative rules that stay compatible with Cartly's calm grocery-decision UI
Use this doc when: creating operator-upload banner images, reviewing sponsor creatives, or later adding slot-aware upload guidance in admin

## 1. Design intent
A Cartly direct banner is not a loud ad block.
It should feel like a **useful side suggestion inside a working grocery surface**.

If one line is needed:

> A Cartly banner should feel like a relevant shopping hint, not a coupon app shouting for attention.

This guide follows `docs/02_product/app-design.md` and must not break these existing rules:
- calm working-surface tone
- no pink emotional styling
- no giant hero theatrics
- no heavy campaign feeling in core app screens
- practical, not cute

## 2. Core banner grammar
Each banner should use the same visual structure as the shipped inline promo slot shell.

### Required layout
- left: compact visual tile or product photo
- center: short title + short support message
- right: small pill CTA
- outer shell: soft warm card with light border

### Required emotional tone
- helpful
- restrained
- trustworthy
- grocery-contextual

### Forbidden tone
- urgent spam
- flashing sale language
- exaggerated discount hype
- generic commerce-feed energy
- casino / lucky-draw / confetti styling

## 3. Slot inventory and artboard baselines
These artboard sizes are design baselines for operator creative review. Runtime can scale, but uploaded images should be composed with these proportions in mind.

| Slot key | Surface | Runtime max height | Recommended artboard | Notes |
| --- | --- | ---: | --- | --- |
| `save_complete_sheet_1` | save complete bottom sheet | 88px | `360x88` | tightest slot, strongest need for brevity |
| `saved_inline_1` | saved list after first card | 104px | `360x104` | best slot for a main sponsor / helpful cross-sell |
| `saved_inline_2` | saved list after third card | 104px | `360x104` | secondary assist slot, lighter message |
| `my_perks_inline_1` | My page below account card | 96px | `360x96` | should feel like a member benefit hint, not a sales push |

## 4. Safe area rules
### Outer shell
- corner radius should visually match app cards: `16px`
- keep a light border around the whole shell
- do not rely on edge-to-edge artwork

### Inner padding
- baseline inner padding: `14px`
- left visual block: `52x52`
- visual-to-text gap: `12px`
- text-to-CTA gap: `10px`

### Text safe area
- title: 1 line preferred
- message: 2 lines max
- avoid composition that requires more than 2 lines to make sense

### CTA safe area
- pill CTA should stay compact
- avoid long button labels that force the card to rebalance awkwardly
- recommended CTA width target: roughly `52–74px`

## 5. Typography
Match the existing app component grammar, not marketing-poster typography.

### Title
- `13px`
- `900`
- dark text
- one-line preferred

### Message
- `12px`
- `600`
- muted dark gray
- max 2 lines
- practical sentence, not slogan poetry

### CTA
- `10px`
- `800`
- pill label only

## 6. Color system
Use Cartly's existing app colors.

### Primary palette
- brand red: `#E31736`
- brand strong: `#C40D2A`
- page/surface base: `#FDFCF8`
- warm soft surface: `#F8F6F1`
- border line: `#E5E7EB`
- title text: `#111111`
- body text: `#4B5563`
- soft red tint for accents only, not full-card flooding

### Recommended shell treatment
- background: warm light gradient from `#F8F6F1` to `#FDFCF8`
- border: `#E5E7EB`
- optional accent chip or icon tile: pale red fill with red icon/text

### Avoid
- hot pink fills
- neon green coupon styling
- saturated black backgrounds
- full-card red blocks inside normal inline placements
- rainbow or heavy drop-shadow treatments

## 7. Image rules
### Preferred image types
- clean product packshot
- simple grocery item grouping
- restrained benefit icon tile
- calm ingredient or pantry visual

### Avoid image types
- busy supermarket photography
- celebrity / human model cutouts
- crowded collage layouts
- tiny multi-product grids
- hard-to-read text baked into the image

### Image treatment
- keep image inside a rounded square tile
- `52x52` visual block should remain legible at a glance
- one hero object is better than many small objects
- product on warm neutral or soft tinted background is preferred

## 8. Copy rules
### Title formula
Use one of these structures:
- benefit first: `장보기 전에 확인할 혜택`
- context first: `이 카트와 같이 보기 좋은 상품`
- member utility: `멤버 전용 혜택 보기`
- Cartly-owned conversion banner: `~해보세요` / `~보세요`

For Cartly's own internal banners, Seungdae's current preference is to avoid flat `~하기` endings and use a more active customer-facing ending like `~보세요` instead.

### Message formula
Use practical helper language:
- what it is
- why it is relevant now
- what happens if tapped

Good examples:
- `자주 담는 카트와 함께 보기 좋은 생활필수품을 모아봤어요.`
- `이번 장보기 흐름을 해치지 않게 짧게 비교해볼 수 있어요.`
- `멤버 혜택과 추천 상품을 한 번에 확인할 수 있어요.`

Bad examples:
- `지금 아니면 놓쳐요!`
- `역대급 초특가!`
- `무조건 사야 하는 핫딜`
- `당장 클릭하세요`

Allowed nuance:
- slightly more commercial phrasing is acceptable for Cartly-owned banners when the visual treatment stays restrained
- prefer direct benefit language over hype language

### CTA labels
Preferred:
- `보기`
- `혜택 보기`
- `자세히`
- `비교하기`
- `확인`
- `바로 보기`
- `추천 보세요`
- `저장해보세요`

Avoid:
- `즉시 결제`
- `쿠폰 받기`
- `무료 증정`
- 과도하게 조급한 강매형 CTA

## 9. Sponsor-fit rules
A sponsor creative can be approved only if:
- it looks native enough to sit between Cartly cards without breaking trust
- it helps a grocery decision or savings decision
- it does not visually dominate the surrounding list
- its copy can be understood in under 2 seconds

A sponsor creative should be rejected if:
- it needs fine print to make sense
- it depends on loud sale theater
- it looks like a different app brand invaded the surface
- it turns Saved or My into a shopping-feed vibe

## 10. Slot-specific guidance
### `save_complete_sheet_1`
Use when:
- cart was just saved
- follow-up suggestion is directly connected to that cart moment

Best tone:
- soft continuation
- "next step" feeling

Do:
- one short title
- one short practical line
- minimal image complexity

Don't:
- heavy promo language
- anything that competes with save-complete confirmation

### `saved_inline_1`
Use when:
- strongest direct banner candidate is available
- a sponsor has clear grocery relevance

Best tone:
- contextual helper
- comparison or replenishment hint

### `saved_inline_2`
Use when:
- secondary suggestion is useful but less important
- category adjacency matters more than hard conversion pressure

Best tone:
- lighter, quieter, more assistive than slot 1

### `my_perks_inline_1`
Use when:
- benefit copy is account or member adjacent
- loyalty / perk / account utility is the main story

Best tone:
- member benefit surface
- no aggressive selling

## 11. First recommended visual direction
Start with **soft neutral shell + compact product tile + small category badge + filled red CTA** as the default house style.

This is the safest first direction because:
- it is more commercial than the plain reference shell without becoming noisy
- it still matches the shipped inline promo component structure
- it will not break the app's calm visual rhythm
- it scales across Saved / My / save-complete surfaces
- it leaves room for stronger sponsor identity later without starting loud

## 12. Example mockups created in this pass
Reference files:
- `docs/02_product/direct-banner-examples/save-complete-soft-benefit.svg`
- `docs/02_product/direct-banner-examples/saved-inline-contextual-grocery.svg`
- `docs/02_product/direct-banner-examples/my-perks-member-benefit.svg`

These are not final campaigns. They are **house-style reference mockups** that show the acceptable visual ceiling for Cartly's first direct-banner wave.

## 13. First live-use internal banner set
Based on Seungdae's 2026-05-20 direction, the first practical Cartly-owned banner set is:

1. **회원가입하고 가족 연동하기**
   - file: `docs/02_product/direct-banner-examples/01-family-link-signup.svg`
   - recommended home surface: `my_perks_inline_1`
   - role: member/family continuity prompt

2. **추천제품으로 합리적인 쇼핑하기**
   - file: `docs/02_product/direct-banner-examples/02-recommendation-rational-shopping.svg`
   - recommended home surface: `saved_inline_1`
   - role: recommendation-assisted shopping guidance

3. **회원가입하고 내 카트 저장하기**
   - file: `docs/02_product/direct-banner-examples/03-signup-save-cart.svg`
   - recommended home surface: `save_complete_sheet_1` or guest-oriented saved flow
   - role: guest-to-member continuity prompt

Important tone decision:
- the underlying campaign ideas stay direct and slightly more commercial
- headline endings should prefer `~보세요` / `~해보세요` over flat noun-style `~하기`
- the latest preferred composition is: **full color background, left-aligned text, right-side graphic design**
- subcopy should stay very short, ideally one compact line or 2-4 strong words
- headline should be shorter and more impact-driven than the earlier drafts
- gradient is no longer preferred for this current internal-banner direction; use solid full-color backgrounds first
- right-side icon/graphic should carry more depth, ideally pseudo-3D or app-icon-like volume rather than flat utility iconography
- the visual execution can move closer to commerce-banner grammar, but should still stop short of noisy discount-app treatment
- exclamation-heavy, pushy retail treatment should still be avoided even for these internal banners

## 14. Implementation follow-ups
Next good implementation slices:
1. show these reference dimensions and rules in the admin slot-aware upload modal
2. add slot-specific helper copy near creative upload
3. add a preview frame that renders the real slot shape before publish
4. optionally add a lightweight creative review checklist: `fit`, `readability`, `context`, `brand noise`
