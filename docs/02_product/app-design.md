# Cartly App Design

Last updated: 2026-05-18
Status: canonical
Purpose: product UI design system and screen grammar for implementation work
Use this doc when: designing or refactoring customer-facing app UI, shared components, or screenshot-facing surfaces

## 1. Design intent
Cartly should feel like a product that helps people **act, review, and decide** during grocery shopping.
The UI is not supposed to feel entertainment-first, feed-first, or heavily promotional.

If an AI agent needs one line:

> Cartly UI should feel like a calm working surface for grocery decisions.

## 2. Product screen grammar

### Home = action
Primary jobs:
- add items
- inspect current total
- keep shopping flow moving
- save the cart

### Explore = decision
Primary jobs:
- revisit same-intent alternatives
- surface meaningful candidates
- support comparison without becoming a generic recommendation feed

### Saved = record
Primary jobs:
- reopen shopping history
- restart from prior carts
- reflect real shopping outcomes cleanly

### My = hub
Primary jobs:
- account continuity
- settings and family sharing
- privacy/support/access surfaces
- light status surfaces like location

### Login = continuity entry
Primary jobs:
- explain why login matters
- preserve guest fallback
- keep the message practical, not over-sold

## 3. Visual language
The app should feel:
- soft but structured
- compact but breathable
- modern but not trendy
- practical, not cute

Avoid:
- pink emotional styling
- giant hero theatrics
- heavy “campaign” feeling in core app screens
- dark contrast overload

## 4. Design tokens and scales

### Typography
- page hero: `30–32 / 700`
- page subtitle: `14 / 500`
- section title: `18 / 800`
- card title: `15–16 / 700–800`
- card body: `13–14 / 500–600`
- key price / strong number: `18–24 / 800`

### Radius
- `12`: compact controls, badges, tight rows
- `16`: default card radius
- `20`: emphasized shell / hero surface
- `999`: pill only

### Surface hierarchy
- `Surface 0`: page background
- `Surface 1`: standard content card
- `Surface 2`: selected / editing / expanded state
- `Surface Brand`: strong CTA or highlighted product shell
- `Surface Contrast`: offer / promo / contrast support surface

### Current color anchors
- page base white: `#FDFCF8`
- selected state: Cartly red
- pink-ish dialog tinting should be removed globally, not patched locally

## 5. Layout rules

### Header behavior
- Home and Explore top header heights should align so the app feels stable, not shaky.
- The top brand area should support the real wordmark height, not crush it into a fallback text state.
- Explore shopping mode should use an immersive red background band that starts under the status bar, not a floating inset card.
- When the shopping-mode red band needs stronger emphasis, prefer extending the background block downward while keeping text and toggle positions stable.
- Body and bottom spacing must not change across Home / Explore / shopping-mode switches just because SafeArea or list padding differs.

### Spacing behavior
- use spacing to create hierarchy before adding new visual styles
- avoid stacking too many identical medium-gray cards with the same padding
- dense working areas are okay, but they must still scan clearly

### Section behavior
- each major section should have a clear role
- if two sections do the same job, merge or demote one
- repeated visual blocks need a meaningful reason to coexist

## 6. Component rules

### Buttons
- one primary action per card or local decision cluster when possible
- secondary actions should clearly read as secondary
- tertiary actions should feel lightweight and inline
- badges must not impersonate CTA buttons

### Cards
Card types should be visually distinct by role:
- action card
- decision card
- info card
- promo/offer card
- editable cart card

If everything looks like the same card, the UI has failed to communicate role.

### Headers
- prefer shared header grammar
- avoid inventing a different visual heading style for every screen

### Brand mark
- use the brand mark as a shell element, not as a giant hero decoration
- wordmark should render as image first where supported

## 7. Screen-specific rules

### Home
- the current cart should feel like a real working surface
- adding items and seeing the total should be immediate and obvious
- the screen should optimize for momentum, not reading long explanations

### Explore
- it is a decision surface, not a help tab and not a generic feed
- every candidate should feel context-linked
- same-intent logic should be visible in wording and structure

### Saved / History
- titles, dates, discount state, and categories should read cleanly
- if receipt purchase date exists, it should dominate customer-facing date presentation
- do not make recent edit timing look like the shopping date

### My
- footer should stay light and inline, not a heavy compliance card
- privacy should open in-app
- account identity, guest/member state, family sharing, and location line should feel like one coherent hub

### Login
- keep benefits realistic and continuity-focused
- do not sound like a growth-hacking campaign

## 8. Receipt and cart UX rules
- do not force a customer-facing diff review workflow
- receipt is the practical source of truth
- after analysis, the UX should invite apply, not paperwork
- undo belongs inside edit context, not as a giant public snackbar choice
- manual price entry stays simple with one visible price field

## 9. Location UX rules
- show one soft status line near identity content, not a history dump section
- phrasing should feel customer-facing and light
- manual refresh must exist
- location refresh must not block scanning flow

## 10. Screenshot and review rules
- App Store screenshots must represent the latest real UI, not preview clones
- public proposal pages should also use real app captures where possible
- fake camera mockups or fabricated scan scenes are not acceptable for Cartly’s current direction

## 11. Working with AI agents
When using this doc as implementation input, preserve these priorities:
1. maintain screen role clarity
2. preserve hierarchy through spacing and structure first
3. keep the UI calm and grocery-utility oriented
4. avoid introducing pink, noisy promo styling, or generic SaaS dashboard tropes into the customer app

## 12. Implementation references
- `lib/app/cartly_ui.dart`
- `lib/app/cartly_app.dart`
- `lib/widgets/cartly_page_header.dart`
- `lib/widgets/cartly_surface_card.dart`
- `lib/widgets/brand_mark.dart`

## 13. When to update this doc
Update when these change:
- token anchors
- header/nav grammar
- screen role rules
- screenshot/review rules
- major shared component conventions

## Related notes
- [[01_brand/brand-system]]
- [[02_product/app-product]]
- [[05_web/web-brand-design]]
