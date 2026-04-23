# Receipt Check (saved-cart-only)

Current Cartly receipt scope is intentionally narrow.

## Product decision

Receipt check runs only from an already-saved cart.

Why:
- the comparison target must already be fixed
- this is a post-shopping verification flow, not an in-store capture flow
- it keeps receipt OCR separate from the faster price-tag scan flow

## Current user flow

1. user opens a saved cart
2. user taps `영수증 비교`
3. user captures or uploads one receipt image
4. backend parses the receipt
5. app shows:
   - simple purchase summary
   - final total vs saved cart total
   - stored receipt detail (image presence + extracted text + parsed line items)
6. user can reopen that stored receipt result later from the same saved cart

## Included scope

- one saved cart -> one receipt check flow
- single receipt image upload
- merchant name / purchased time / total amount extraction when possible
- parsed receipt line-item storage
- final-total comparison between saved cart and receipt
- stored receipt text/detail for later review

## Explicitly out of scope

- item-by-item reconciliation workflow
- manual apply / confirm flow that mutates the saved cart
- add/remove cart items from receipt review
- unresolved review buckets like `price_diff`, `receipt_only`, `cart_only`, `review_needed`
- multi-page receipt stitching
- returns / exchanges / cancel receipts
- historical analytics across many receipts

## Active API

- `POST /v1/receipts`
  - multipart: `savedCartId`, `image`
- `GET /v1/receipts/{id}`
- `GET /v1/receipts/{id}/result`

`GET /v1/receipts/{id}/result` returns:
- `receipt`
- `lineItems`

There is no manual confirm/apply endpoint in the active scope.

## Backend behavior

- uploaded receipt image is stored under receipt storage
- receipt OCR/analysis runs through `scripts/openclaw_receipt_runner.py`
- backend persists receipt summary fields and parsed line items
- saved cart total is compared at the app/UI layer for the customer-facing summary

## UI expectations

Result screen should emphasize:
- `영수증으로 확인한 결과, N개의 상품 N원에 구매했어요!`
- final total comparison
- stored detail visibility
- retry / re-upload actions

It should not present manual reconciliation actions.
