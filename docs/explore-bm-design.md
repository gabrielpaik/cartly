# Explore BM / UX Design

Last updated: 2026-04-28

## 1. Product definition

Explore is not a generic recommendation tab.

Explore is an **intent-aware commerce surface** that changes role by user state.

It has two monetization lanes:

1. **Same-intent substitution**
   - Example: a user scans or adds milk, and Cartly shows a better-value milk option.
   - Best fit during active shopping.
2. **Store-context promotions**
   - Example: when the user is idle or currently at a specific mart, Cartly shows relevant offline sale/event information.
   - Best fit outside active shopping, or when store context is confidently known.

Core rule: monetization must feel like **decision support**, not like an ad feed.

## 2. Persona model

### 2.1 Surface persona: practical shopper

- Wants to finish shopping quickly.
- Does not want to compare everything manually.
- Dislikes ads, but accepts help when it is clearly relevant.
- Will act on a better option if the comparison cost is near zero.

### 2.2 Conversion persona: value-sensitive but low-effort user

- Not an extreme bargain hunter.
- Will switch if the improvement is obvious enough.
- Does not want to browse recommendations for fun.
- Responds when the offer is framed as a better answer to the same job.

### 2.3 Future supply-side persona: retailer / sponsor

- Wants to buy exposure in a context where the user is already shopping or about to shop.
- Cares about store-specific visibility, sale/event awareness, and local conversion.
- Needs operational controls by store, time window, category, and context trigger.

## 3. Explore state model

Explore should behave like a state machine, not a fixed screen.

### A. Active shopping

Triggered when at least one is true:
- current cart has items
- recent scan queue exists
- unresolved review/decision items exist

Primary user job:
- decide what to buy right now

Primary BM lane:
- same-intent substitution

Primary sections:
1. offer slots (if available, top priority)
2. decision inbox
3. revisit items
4. summary card

Hidden/de-emphasized:
- saved cart context
- repeat-buy planning
- general store promos

### B. Post-save

Triggered when:
- a shopping session just ended with save

Primary user job:
- close the loop and seed the next trip

Primary BM lane:
- lightweight follow-up suggestion, low intensity

Primary sections:
1. save-complete summary
2. repeat-buy seed from this trip
3. one light same-intent follow-up opportunity

This is transitional, not a long-stay screen.

### C. Idle planning

Triggered when:
- no active cart
- no recent scan queue
- no open review context

Primary user job:
- re-enter shopping later with less effort

Primary BM lane:
- repeat-buy based substitution
- low-pressure retailer discovery

Primary sections:
1. saved shopping context
2. repeat-buy candidates
3. repeat-buy based offer slots

Hidden:
- active-shopping summary
- active decision inbox
- revisit-from-scan surfaces

### D. Store-context mode

Triggered when store context is known with confidence:
- user manually selected a mart
- user is physically at a specific mart
- recent saved cart / trip context strongly points to a store
- future receipt/location/store-history heuristics confirm store identity

Primary user job:
- understand what is worth buying at this mart now

Primary BM lane:
- offline store promotions
- store-paid placements
- category-relevant local sale/event info

Primary sections:
1. this-store-now promotions
2. user-history-matched sale items
3. same-intent substitutions available at this store
4. saved / repeat context below

Important: this should still feel useful, not like a flyer dump.

## 4. UX principles

### 4.1 No generic ad feed

Explore must never degrade into a vertical feed of unrelated offers.

### 4.2 Every monetized surface needs context

An offer must answer:
- why is this here now?
- what current shopping job does it help?
- why is it better than the current/default option?

### 4.3 Same-intent only for product substitution

No cross-sell.

Allowed:
- same category
- same purpose
- similar size/composition
- better price / value / bundle / quality signal

Not allowed:
- unrelated upsell
- basket-expansion junk
- entertainment-style recommendation feed

### 4.4 Store promotions also need user relevance

Offline promotions should be filtered by:
- likely basket intent
- repeat-buy history
- saved-cart history
- store context

That keeps retailer monetization aligned with user utility.

## 5. Section behavior by state

### Active shopping

- **Offer slots**: float to the top when present
- **Dismiss**: user can hide individual offer cards with X
- **Decision inbox**: should gather unresolved, comparison-worthy items
- **Revisit items**: should stay tight and action-oriented
- **Summary**: useful but secondary to offers/inbox

### Idle planning

- **Saved context** becomes the top section
- **Repeat-buy candidates** become the main seed list
- **Offer slots** are generated from repeat-buy intent, not from live cart/scan intent
- active-shopping sections should disappear

### Store-context mode

- store promotions can outrank repeat-buy sections if confidence is high
- same-intent offers can still exist, but should be scoped to the known store when possible

## 6. Admin operating model

Explore admin should not just be copy editing.

It should evolve into an operator surface with at least these layers:

### 6.1 State layout control

Per state:
- active shopping
- post-save
- idle planning
- store-context

For each state:
- enabled sections
- section order
- max visible counts
- emphasis / prominence controls

### 6.2 Intent offer controls

- substitution rules
- ranking policy
- cooldown / dismiss behavior
- max offer count by state
- CTA tone and copy guardrails

### 6.3 Store promotion controls

- store campaign enablement
- store / region targeting
- date/time window
- category matching
- sponsor priority / override
- fallback behavior when exact store context is missing

### 6.4 Preview

Preview should support explicit state toggles:
- active shopping
- idle planning
- future store-context

Eventually also:
- selected store context
- repeat-buy heavy user vs light user
- discount-heavy week vs normal week

## 7. Data / signal model

### 7.1 User-state signals

Needed now or soon:
- current cart item count
- recent scan count
- unresolved review count
- recently saved cart timestamp
- repeat-buy score by item / intent

### 7.2 Intent signals

- normalized item / intent key
- source type (`currentCart`, `pendingReview`, `repeatPurchase`)
- reference price
- recency
- confidence / urgency

### 7.3 Store-context signals

Future-ready model should allow:
- selected store id
- detected store id
- store confidence score
- store name / brand / branch
- store-type taxonomy (costco / emart / homeplus / etc.)
- valid promo window

### 7.4 Monetization object split

Explore should eventually distinguish at least two content objects:

1. `ExploreIntentOffer`
   - same-intent substitution
   - product/price/value comparison oriented
2. `ExploreStorePromo`
   - offline promotion / event / sponsored slot
   - store/time/category scoped

Do not force both into one generic ad-slot model long term.

## 8. Recommended implementation order

### Phase 1, current
- active shopping vs idle planning state split
- dynamic section order
- offer slots top-priority during active shopping
- dismissible offer cards
- preview toggle for active vs idle

### Phase 2
- explicit `ExploreState` model in runtime/app-config
- post-save micro-state
- admin state-by-state layout controls
- persistent dismiss scope decision (session/day/intent-based cooldown)

### Phase 3
- store-context data model
- store-aware preview/admin controls
- offline promo objects and rendering blocks
- store-targeted ranking and fallback logic

### Phase 4
- retailer-facing campaign operations
- attribution / click / downstream conversion history
- reporting by state, intent, store, and campaign

## 9. Decisions to lock before deeper implementation

1. What ends an active shopping session?
   - save cart
   - inactivity timeout
   - explicit end-session action

2. How long should dismiss on an offer last?
   - until cart changes
   - until session ends
   - per intent cooldown

3. How should store context be acquired first?
   - manual store selection
   - location inference
   - receipt/store-history inference

4. What is the first store-promo ingestion path?
   - admin manual campaign entry
   - CSV/import
   - partner API later

## 10. Summary

Explore should be treated as a commerce state machine.

- During **active shopping**, it is a same-intent decision and substitution engine.
- During **idle planning**, it is a repeat-buy and re-entry engine.
- During **store-context**, it becomes a localized offline retail monetization surface.

The business model is not only recommendation.
It is the broader system of **contextual shopping conversion**, spanning both product substitution and store-aware offline promotion.
