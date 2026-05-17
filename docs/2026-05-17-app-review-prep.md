# 2026-05-17 Cartly App Review prep

## Current submission target
- app version/build: `1.0.4 (25)`
- latest upload delivery UUID: `52229c14-bfeb-42ef-83ae-3a72c4f4cd8c`
- App Store Connect processing state: `VALID`

## What is review-relevant and already in place
- in-app account deletion exists for member accounts
- privacy policy is reachable from My page and opens inside the app
- public privacy URL is live at `https://scan-api.seoa-nas.com/privacy`
- guest mode exists, so core browsing/cart usage is possible without signup
- family sharing is member-only and clearly separated from guest mode
- location usage is foreground only, one-time read style, for nearby market discount info
- app does not use non-exempt encryption (`ITSAppUsesNonExemptEncryption = false`)

## Review-risk cleanup completed in this pass
- removed `NSLocationAlwaysAndWhenInUseUsageDescription` from `ios/Runner/Info.plist`
- reason: product and implementation are foreground-only; keeping an always-location purpose string would create unnecessary App Review risk

## Recommended App Review notes (paste into App Store Connect)
Cartly helps users track grocery carts, save shopping history, scan shelf labels/receipts, and browse nearby market discount information.

Important review notes:
1. Guest mode is available, so the app can be opened and used without creating an account.
2. Member-only features include profile management, family sharing, and account deletion.
3. Account deletion path: My Page -> 수정 및 가족공유 -> 탈퇴하기.
4. Privacy policy path: My Page footer -> 개인정보 처리방침. It opens in-app.
5. Location permission is used only while the app is in use, only for nearby market discount information. There is no background location tracking.
6. External shopping links are opened only after the user explicitly taps a recommendation or offer.
7. Family sharing is optional and requires two member accounts. Core app use does not depend on family sharing.

## Recommended reviewer test path
### Basic no-account path
1. Launch app
2. Continue in guest mode
3. Add items to current cart
4. Save and browse cart history
5. Open My Page -> 개인정보 처리방침

### Member path
1. Create or log into a member account
2. Open My Page -> 수정 및 가족공유
3. Change display name
4. Confirm account deletion entry is visible via 탈퇴하기

### Optional family-sharing path
1. Use two member accounts
2. Generate household invite code on account A
3. Join from account B
4. Confirm shared saved carts/current cart behavior

## Remaining non-code submission tasks
- fill App Review notes in App Store Connect using the draft above
- verify privacy policy URL is entered in App Privacy / App Information fields where needed
- confirm screenshots match the current family-sharing/settings UI, not the older popup/menu variant
- add a short note that guest mode exists and login is only required for member features

## Current judgment
- code-side review readiness looks close
- biggest avoidable iOS review footgun was the unnecessary always-location plist key, and that is now removed
- the next practical step is metadata/review-note cleanup in App Store Connect, then final submission prep
