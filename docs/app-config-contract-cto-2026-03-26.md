# Cartly `/v1/app-config` CTO Contract

Date: 2026-03-26
Status: Proposed / next implementation target

## 1. Goal

`/v1/app-config` should become the single runtime contract between:

- Admin control plane
- Backend source of truth
- Flutter app runtime rendering

This endpoint must be enough for the app to boot with runtime-managed:

- branding
- UI copy
- ads placement/config
- feature flags
- support/runtime metadata

The app should not depend on scattered hardcoded copy for core product surfaces once this contract is complete.

---

## 2. Current observed state

### Backend already returns

- `features.remoteScan`
- `features.adsEnabled`
- `branding.*`
- `adSlots[]`

### Branding currently includes

- logo mode/text/assets
- tab labels
- Saved / My / Login / Save Complete copy

### Ad slots currently include

- slot key
- placement type
- enabled
- runtime config:
  - maxHeight
  - screen
  - position
  - tone
  - title
  - message
  - ctaLabel
  - targetUrl
  - imageUrl
  - campaignId

### App still has significant hardcoded copy in Flutter

Observed hardcoded surfaces still outside app-config:

- Home page section titles / subtotal area / current cart prompts
- Login provider button labels and validation messages
- Cart detail page action labels and dialogs
- OCR / scan UX messages
- Manual add / result review labels
- Some ad fallback display strings
- Guest/account drawer strings

Conclusion:

`branding` is currently overloaded as a partial copy bucket.
It works for phase 1, but it is not a scalable runtime contract for the whole app.

---

## 3. CTO decision

Split runtime app contract into **four stable domains**.

```json
{
  "features": {},
  "branding": {},
  "copy": {},
  "ads": {}
}
```

### Why

- `branding` = visual identity / shell labels
- `copy` = user-facing app text
- `ads` = runtime slot/campaign placement contract
- `features` = runtime toggles

This keeps admin editing clean and prevents branding fields from becoming an unstructured dump.

---

## 4. Target response shape

```json
{
  "ok": true,
  "data": {
    "version": 1,
    "generatedAt": "2026-03-26T00:00:00Z",
    "features": {
      "remoteScan": true,
      "adsEnabled": true,
      "manualAddEnabled": true,
      "guestModeEnabled": true,
      "savedCartEditingEnabled": true
    },
    "branding": {
      "logoType": "text_image",
      "logoText": "What's in my cart",
      "logoImageUrl": "...",
      "splashImageUrl": "...",
      "tabs": {
        "home": "Home",
        "saved": "Saved",
        "my": "My"
      }
    },
    "copy": {
      "home": {},
      "saved": {},
      "my": {},
      "login": {},
      "saveComplete": {},
      "cartDetail": {},
      "scan": {},
      "common": {}
    },
    "ads": {
      "slots": []
    }
  }
}
```

---

## 5. Domain-level contract

## 5.1 Features

Purpose: toggle behavior, not display copy.

Proposed fields:

- `remoteScan`
- `adsEnabled`
- `manualAddEnabled`
- `guestModeEnabled`
- `savedCartEditingEnabled`
- later: `emailSignupEnabled`, `kakaoEnabled`, `googleEnabled`

Rule:
- booleans only
- app should be able to hide/disable UX paths directly from these flags

---

## 5.2 Branding

Purpose: visual identity and shell labels only.

Proposed fields:

- `logoType`
- `logoText`
- `logoImageUrl`
- `splashImageUrl`
- `tabs.home`
- `tabs.saved`
- `tabs.my`

Move out of branding:
- page titles
- empty-state messages
- login benefit text
- save-complete text

Those belong in `copy`.

---

## 5.3 Copy

Purpose: all user-facing app strings that should be runtime-editable.

### `copy.common`

- `save`
- `cancel`
- `edit`
- `done`
- `delete`
- `retry`
- `confirm`
- `loading`
- `empty`

### `copy.home`

- `subtitle`
- `recentScanTitle`
- `recentScanSubtitle`
- `addSectionTitle`
- `addSectionSubtitle`
- `currentCartTitle`
- `currentCartSubtitle`
- `currentCartEmpty`
- `addToCurrentCartDone`
- `saveCartButton`
- `cartTotalLabel`

### `copy.saved`

- `pageTitle`
- `subtitle`
- `emptyTitle`
- `emptyBody`
- `recentTitle`
- `recentEmptyBody`
- `viewSavedAction`

### `copy.my`

- `pageTitle`
- `subtitle`
- `benefitsTitle`
- `benefitsBody`
- `guestTitle`
- `guestBody`
- `loginAction`
- `logoutAction`
- `linkedDoneMessage`
- `logoutDoneMessage`

### `copy.login`

- `pageTitle`
- `subtitle`
- `benefitsTitle`
- `benefitsBody`
- `nameFieldLabel`
- `emailFieldLabel`
- `emailSubmit`
- `continueAsGuest`
- `provider.kakao`
- `provider.google`
- `provider.email`
- `submitting`
- `validation.nameEmailRequired`

### `copy.saveComplete`

- `title`
- `subtitle`
- `continueScanAction`

### `copy.cartDetail`

- `titleSuffix`
- `edit`
- `done`
- `deleteDialogTitle`
- `deleteDialogBody`
- `deleteConfirm`
- `deleteCancel`
- `empty`
- `itemAdded`
- `savedSnapshotDone`
- `nameLabel`
- `priceLabel`
- `apply`
- `totalLabel`
- `saveButton`
- `saving`

### `copy.scan`

- `captureButton`
- `uploadButton`
- `cameraFallbackMac`
- `cameraFallbackWindows`
- `cameraFallbackLinux`
- `cameraFallbackDefault`
- `uploading`
- `queued`
- `processing`
- `resultPreparing`
- `failed`
- `timeout`
- `resultEmpty`
- `processingError`
- `recognizedTitle`
- `manualAddTitle`
- `manualAddAction`
- `recognizeAction`
- `retakeAction`
- `cameraPreparing`
- `confidence.high`
- `confidence.medium`
- `confidence.low`
- `review.high`
- `review.medium`
- `review.low`
- `nameLabel`
- `priceLabel`
- `rawTextPrefix`
- `sourceLabel`
- `skuLabel`

Rule:
- app UI must stop introducing new hardcoded user-facing strings without adding them to this contract
- backend may still send Korean defaults; admin can override them later

---

## 5.4 Ads

Current shape is already close.

Target shape:

```json
"ads": {
  "slots": [
    {
      "slotKey": "saved_inline_1",
      "placementType": "inline",
      "enabled": true,
      "config": {
        "screen": "saved_list",
        "position": "after_first_card",
        "maxHeight": 104,
        "tone": "benefit_native",
        "title": "...",
        "message": "...",
        "ctaLabel": "...",
        "targetUrl": "...",
        "imageUrl": "...",
        "campaignId": "..."
      }
    }
  ]
}
```

Recommendation:
- nest ad slots under `ads.slots`
- keep app parsing code compatible during migration

---

## 6. Admin mapping

Admin should edit these through **separate bounded surfaces**.

### Admin -> Branding
- logo mode/text/images
- tab labels

### Admin -> App Copy
- all end-user copy fields
- ideally in grouped sections matching app screens

### Admin -> Ads
- slot config / live campaign / reserved campaign

Do **not** keep expanding `branding` page indefinitely.
Create or evolve a dedicated **App Copy** editor page if needed.

---

## 7. Flutter migration plan

## Phase A — safe compatibility layer

1. Keep existing `branding` fields working
2. Add new `copy` object to `/v1/app-config`
3. App loads:
   - `branding` first
   - `copy` second
4. Existing screens keep working while new copy getters are introduced

## Phase B — runtime text abstraction

Create a central app runtime text accessor, e.g.

- `AppRuntimeCopy.home.subtitle`
- `AppRuntimeCopy.login.providerKakao`
- `AppRuntimeCopy.scan.processing`

No page should read raw JSON directly.

## Phase C — remove hardcoded strings

Move current hardcoded strings from:
- `main.dart`
- `login_page.dart`
- `cart_detail_page.dart`
- `item_add_section.dart`

into `copy.*`

## Phase D — admin editing completion

Expose all `copy.*` fields in admin UI grouped by app screen.

---

## 8. Backward compatibility rules

1. `branding.*` existing keys remain supported until Flutter migration completes
2. `adSlots` may remain top-level for one transition window, but target is `ads.slots`
3. every new field must have backend default fallback
4. app must tolerate missing sections and fallback locally during migration only

---

## 9. Immediate implementation recommendation

### Next backend work

1. extend `/v1/app-config` to include:
   - `version`
   - `generatedAt`
   - `copy`
   - `ads.slots`
2. keep current `branding` and `adSlots` temporarily for compatibility
3. add app-settings storage buckets:
   - `app_copy`
   - `app_features`
   - optionally `app_tabs`

### Next Flutter work

1. create `AppCopy` model
2. extend `AppConfigStore` to parse `copy`
3. replace hardcoded strings on these screens first:
   - login page
   - home main shell
   - scan flow
   - cart detail

### Next admin work

1. promote current content page into full app copy editor
2. split groups by screen
3. keep branding fields separate from general copy

---

## 10. CTO priority

Recommended execution order:

1. backend contract expansion for `/v1/app-config`
2. Flutter `AppCopy` model + store
3. replace hardcoded app strings on main user flows
4. internal app eye review / TestFlight
5. then OCR quality + scan UX refinement

This order closes the loop:

**admin edits -> backend contract -> app runtime rendering**

Without this, admin improvements stay operationally useful but not product-complete.
