# Cartly UI progress handoff - 2026-05-07

## What was completed

### 1) Current cart naming UX cleanup
- Replaced the narrow bottom-sheet style full-name popup with inline card expansion in the current cart.
- Users can now:
  - expand the cart item card itself,
  - see the full product name in place,
  - edit the display name directly inside the card.
- Quantity controls and total price stay visible in the same card context.

### 2) Display name vs original OCR name split
- Preserved the user-facing editable label as the main display `name`.
- Preserved the OCR/source name separately as:
  - app runtime: `originalRecognizedName`
  - saved cart / backend payload: `originalName`
  - DB column: `cart_items.original_name`
- Goal: let the UI rename products without destroying the original recognition reference needed for later analysis and receipt comparison.

### 3) Persistence and backend wiring
- Wired the split-name model through:
  - current cart local persistence
  - recent scan persistence
  - saved cart serialization
  - backend cart request schema
  - backend cart item serialization
  - backend DB migration/model
- Duplicate matching for scan results was intentionally kept anchored to the original recognized name so manual display-name edits do not break merge behavior.

### 4) Receipt comparison cleanup
- Receipt detail now counts only purchasable line items as products.
- Discount / coupon / tax / subtotal / payment rows are separated as supporting reference rows instead of being counted as purchased products.

### 5) Home / Explore IA cleanup
- Home keeps execution focus.
- Explore is simplified around the agreed decision-surface model.
- Active shopping Explore now centers on `결정 인박스`.
- Post-shopping Explore is reduced to the agreed lower-noise flow.

## Validation status
- Flutter analyze passed.
- Backend compile check passed.
- iOS IPA build completed as `1.0.3 (78)`.

## Latest user feedback
- User response after real-device check: `좋아 훨씬 깔끔해 진것 같다.`
- This is a positive signal specifically for the current cart naming / presentation cleanup direction.

## Key files touched
- `lib/widgets/current_cart_section.dart`
- `lib/pages/home_page.dart`
- `lib/pages/home_tab_view.dart`
- `lib/pages/home_page_cart_controller.dart`
- `lib/pages/home_page_cart_save_controller.dart`
- `lib/services/current_cart_store.dart`
- `lib/models/recognized_item.dart`
- `lib/models/saved_cart.dart`
- `lib/app_support.dart`
- `backend/app/schemas/cart.py`
- `backend/app/services/cart_service.py`
- `backend/app/db/models.py`
- `backend/app/db/init_db.py`
- `lib/pages/receipt_comparison_page.dart`
- `lib/pages/shopping_help_page.dart`

## Next stage
Next, review and absorb the design-system markdowns provided by the user, then evaluate Cartly’s current design system quality and propose improvements.

Planned focus:
1. learn the user-authored design-system docs,
2. evaluate Cartly against those principles,
3. identify the biggest system-level design inconsistencies,
4. improve Cartly design with a system-first lens rather than one-off screen polish.
