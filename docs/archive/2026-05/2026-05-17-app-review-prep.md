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

## Metadata progress update
- App Store Connect app info localization has now been updated to:
  - name: `카트리`
  - subtitle: `장보기 기록과 대체안 탐색`
  - privacy policy URL: `https://scan-api.seoa-nas.com/privacy`
- App Store Connect version localization has now been updated to:
  - Korean description
  - expanded keywords including Korean/English variants and common typo coverage
  - marketing URL: `https://scan-api.seoa-nas.com/`
  - support URL: `https://scan-api.seoa-nas.com/support`
- Public support page is now live at `https://scan-api.seoa-nas.com/support` and exposes the reachable support email `scancart.wimc@gmail.com`.
- App Review contact is now saved:
  - contact email: `scancart.wimc@gmail.com`
  - contact phone: `+82 10-9112-5123`
- Current App Store version `1.0` is now attached to build `1.0.4 (25)` (`52229c14-bfeb-42ef-83ae-3a72c4f4cd8c`).

## Remaining non-code submission tasks
- confirm screenshots match the current family-sharing/settings UI, not the older popup/menu variant
- complete Age Rating questionnaire in App Store Connect
- complete / verify App Privacy questionnaire in App Store Connect
- final submit for review

## Android / Google Play launch snapshot
- Android release AAB build now succeeds locally: `build/app/outputs/bundle/release/app-release.aab`
- current Android package id: `com.seungdae.cartly`
- release signing is now wired to `android/key.properties` when present, with debug-signing fallback only when local signing data is absent
- a local upload keystore has been created outside the repo and connected for release builds
- helper script added: `scripts/build-android-play-release.sh`
- there is still no Play Console automation path in-repo (no `fastlane supply`, no Play service-account credential found)

## Current judgment
- iOS metadata, screenshots, privacy/support URLs, review contact, and build attachment are now substantially cleaned up
- code-side review readiness looks close
- biggest avoidable iOS review footgun was the unnecessary always-location plist key, and that is now removed
- Android is now buildable as a signed release AAB locally, but Google Play launch is still blocked on Play Console-side work: app creation/access, Data safety, Content rating, App access, and actual upload/release-track submission
- the next practical step is final store-console submission prep on iOS plus Play Console setup/upload on Android
