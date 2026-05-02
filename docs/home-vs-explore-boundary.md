# Home vs Explore Boundary

Last updated: 2026-04-28

## 1. One-line rule

- **Home = execution tab**
- **Explore = decision / conversion tab**

If a user is trying to **do** something now, it should usually live in Home.
If a user is trying to **judge, compare, reconsider, or re-enter** a shopping flow, it should usually live in Explore.

---

## 2. Home responsibility

Home owns the active shopping workflow itself.

### Home should own
- scan / capture flow
- OCR processing queue
- manual add flow
- recognized result confirmation
- add-to-cart action
- current cart list
- quantity edit
- remove from cart
- save cart

### Home should show
- raw recent scan queue
- current cart details
- immediate add/edit/save actions

### Home should not become
- a recommendation feed
- a long comparison surface
- a repeat-buy planning surface
- a retailer promo surface

### Home mental model
"I am shopping right now. Let me add, edit, and save things."

---

## 3. Explore responsibility

Explore owns judgment, re-entry, and monetized conversion surfaces.

### Explore should own
- decision inbox
- reconsider / revisit candidates
- same-intent substitution offers
- repeat-buy candidate surfaces
- saved shopping context for re-entry
- future store-context promos / offline sale surfaces

### Explore should show
- curated decision support
- ranked opportunities
- context-aware monetization
- state-dependent layout

### Explore should not become
- a raw scan queue clone
- a cart editor
- a save flow surface
- a generic ad feed

### Explore mental model
"Help me make better shopping decisions, now or before the next trip."

---

## 4. Overlap review and resolution

## 4.1 Recent scan queue vs decision inbox

### Potential overlap
- Home already shows recent scans.
- Explore also wants to show unresolved shopping decisions.

### Resolution
- **Home recent scans = raw processing queue**
- **Explore decision inbox = curated queue**

Explore should never mirror the entire recent scan queue.
Each Explore item must have a reason to exist, such as:
- has same-intent alternative available
- high-value item worth reconsidering
- already added to cart but comparison value remains
- unresolved decision with downstream impact

### Rule
If the item is just "something that was scanned", keep it in Home.
If the item is "something worth deciding again", elevate it to Explore.

---

## 4.2 Current cart vs summary card

### Potential overlap
- Home owns current cart details.
- Explore also wants shopping-state awareness.

### Resolution
- **Home = cart editing**
- **Explore = cart interpretation**

Explore may show:
- item count
- total price
- unresolved decision count
- number of active offers

Explore should not show:
- full editable cart rows
- quantity controls
- remove actions

### Rule
Cart manipulation belongs to Home.
Cart context belongs to Explore.

---

## 4.3 Recent saved cart preview vs saved context

### Potential overlap
- Home currently shows `RecentSavedPreviewCard` at the bottom.
- Explore idle mode wants saved-context-first UX.

### Resolution
Long-term, this should move toward Explore.

Recommended direction:
- Home keeps, at most, a lightweight shortcut or compact CTA.
- Explore becomes the primary place for:
  - last shopping context
  - repeat-buy candidates
  - re-entry into the next trip
  - future store-aware promos

### Rule
Past-trip re-entry belongs to Explore more than Home.

---

## 5. State-based responsibility

## 5.1 Active shopping

### Home priority
- capture
- OCR queue
- cart building
- save

### Explore priority
- same-intent substitution
- decision inbox
- revisit-worthy items
- compact progress summary

### Important
Explore can influence decisions, but should not duplicate execution controls.

---

## 5.2 Idle planning

### Home priority
- minimal or no planning-heavy content

### Explore priority
- saved context
- repeat-buy candidates
- repeat-buy derived offers
- future offline retail promo surfaces

### Important
Idle planning should concentrate in Explore, not fragment across tabs.

---

## 5.3 Store-context mode

### Home priority
- still execution if user is actively shopping

### Explore priority
- current-store sales/events
- relevant retailer promos
- store-aware same-intent alternatives

### Important
Store monetization should be additive to context, not a detached flyer feed.

---

## 6. Decision rubric

When deciding where a surface belongs, ask:

1. Is this about **doing** or **deciding**?
   - doing -> Home
   - deciding -> Explore

2. Is this **raw workflow state** or **curated opportunity**?
   - raw -> Home
   - curated -> Explore

3. Is the user trying to finish the current trip or prepare the next one?
   - current trip execution -> Home
   - next-trip re-entry / conversion -> Explore

4. Does this surface exist mainly because of monetization?
   - if yes, it must still be contextually useful and usually belongs in Explore

---

## 7. Immediate product decisions

## Keep in Home
- scanner UI
- OCR queue
- add-to-cart flow
- full current cart
- save flow

## Keep in Explore
- same-intent offer slots
- decision inbox
- revisit list
- repeat-buy candidates
- saved-context re-entry
- future store promos

## Shrink or move from Home over time
- recent saved preview block

## Never clone into Explore
- full raw scan queue
- cart quantity editor
- remove-from-cart controls

---

## 8. Recommended next implementation slices

### Slice A
Make the boundary more explicit in UI copy and hierarchy.
- Home language should emphasize capture / add / cart / save.
- Explore language should emphasize compare / decide / revisit / next trip.

### Slice B
Reduce Home's saved-cart prominence.
- downgrade `RecentSavedPreviewCard` in Home to a smaller shortcut
- keep the full re-entry experience in Explore

### Slice C
Strengthen Explore curation logic.
- ensure decision inbox only shows ranked/reasoned items
- ensure raw queue remains Home-only

### Slice D
Prepare future store lane.
- keep Explore architecture ready for store promos without polluting Home

---

## 9. Summary

Home and Explore should not compete.

- **Home** is where a user executes the current shopping trip.
- **Explore** is where Cartly helps the user make better decisions and creates monetizable conversion opportunities.

The user should never wonder why the same job exists in both tabs.
