# Cartly Release Management

Last updated: 2026-05-29
Status: canonical
Purpose: release operations contract for iOS, TestFlight, App Store Connect, and Google Play
Use this doc when: building, uploading, patching store metadata, or preparing submission/review steps

## 1. release 운영 원칙

### 기본 규칙
- 릴리즈용 앱 빌드를 만들기 전에 **반드시 build number를 먼저 올린다**.
- 사용자가 명시적으로 멈추라고 하지 않는 한, **성공한 iOS 빌드는 TestFlight/App Store Connect 업로드까지 이어간다**.
- Android도 같은 release cycle에서 함께 빌드하고, 가능하면 **internal testing track 업로드까지 같은 턴에 진행한다**.
- 사용자 현재 운영 원칙: iOS TestFlight만 따로 밀지 말고, Android도 계속 같은 버전 흐름으로 함께 올리며 중간중간 실제 Android 폰에서 함께 눈검수한다.
- Cartly release 기본 운영 규칙은 **iOS TestFlight와 Android internal testing을 같은 build cycle에서 같이 돌리는 것**이다.
- 최종 store 승인/제출도 특별한 예외 지시가 없으면 **iOS와 Android를 한 세트로 맞춰 동시에 진행**한다.
- release 변경은 가능하면 별도 release commit으로 남긴다.
- 스크린샷/메타데이터/리뷰 노트까지 같이 관리해야 진짜 release readiness다.

### 현재 기준 버전
- current working app version/build: `1.0.8+18`
- latest shipped iOS public release line: `1.0.8 (18)`
- current public App Store URL: `https://apps.apple.com/kr/app/카트리/id6763728346`
- latest uploaded iOS App Store build: `1.0.8 (18)` / delivery UUID `65b9c131-01e8-495f-86bf-762f0e6c5477`
- the same `1.0.8 (18)` line is now publicly live on the App Store, with delivery UUID `65b9c131-01e8-495f-86bf-762f0e6c5477`
- most recent later iOS validation uploads in the same pass: `1.0.7 (15)` / `80957366-da62-4f31-9ddb-5fb5420f6e60`, `1.0.7 (16)` / `134ece29-f48f-4bc7-87ae-8a2665a1507f`, `1.0.7 (17)` / `e5fb66ce-38b8-4b11-b3b8-4cb08bfe0d4b`, `1.0.8 (18)` / `65b9c131-01e8-495f-86bf-762f0e6c5477`
- most recent earlier iOS validation uploads in the same pass: `1.0.6 (10)` / `aa51303b-a5bc-4410-a5c0-e3e88eeda483`, `1.0.6 (9)` / `28566327-afb0-48c3-9951-11b8b099dbe9`, `1.0.6 (8)` / `d176d4a8-f775-4a2e-8edd-47b518873c3c`, `1.0.6 (7)` / `9fac0cc3-5b5e-4afc-8f5c-7dc72218007c`
- latest visible iOS TestFlight Cartly build on device before this reset: `1.0.4 (29)`
- latest uploaded Android internal-track build after this reset: `1.0.8 (47)`
- latest prepared Android release artifact after this reset: versionName `1.0.8`, versionCode `47`, AAB `build/app/outputs/bundle/release/app-release.aab`

### 2026-05-19 version reset policy
- `1.0.4` 라인은 TestFlight/App Store Connect 쪽 build numbering 혼선 때문에 더 늘리지 않는다.
- 모든 개발 검수 / 디자인 튜닝 / TestFlight 확인은 이제 `1.0.5 (xx)` 라인에서 진행한다.
- Android도 별도 보류하지 말고 같은 `1.0.5 (xx)` 흐름으로 internal testing 업로드를 계속 맞춘다.
- 단, Google Play `versionCode` 는 전역 증가 제약이 있으므로 `1.0.5 (1)` 리셋과 별개로 Android 업로드 코드는 이전 `27` 보다 큰 값으로 계속 증가시킨다. 현재 최신 업로드 값은 `versionCode 40` 이다.
- 이 리셋의 시작점은 `1.0.5 (1)` 이다.
- 최종 출시 라인은 `1.0.6 (1)` 부터 시작하는 것으로 고정한다.
- 따라서 다음 업로드부터는 customer-facing version surface도 `1.0.5 (1)` 기준으로 다시 정렬하는 것을 기본 원칙으로 삼는다.

### 2026-05-18 release surface alignment note
- app, admin, 공개 웹 customer-facing copy 기준값은 `1.0.4 (27)` 로 맞춘다.
- 공개 지원 메일은 `cartly.support@gmail.com` 을 기준으로 유지한다.
- `Explore` 같은 예전 customer-facing 표현은 공개 표면에서는 `탐색` 또는 한국어 문맥 표현으로 정리한다.
- 소스 수정만으로 끝내지 말고, `app_copy` 런타임 값과 공개 웹 응답까지 같이 확인한다.

## 2. iOS release 흐름

### 1) 버전 올리기
- 파일: `pubspec.yaml`
- 예: `version: 1.0.4+25`

### 2) 빌드
사용 스크립트:
```bash
/Users/sdpaik/dev/cartly/scripts/build-ios-testflight-public.sh
```

역할:
- `flutter build ipa --release`
- `CARTLY_REMOTE_BASE_URL`
- `CARTLY_APP_CONFIG_BASE_URL`
주입

기본 public target:
- `https://scan-api.seoa-nas.com`

### 3) IPA 산출물
기본 경로:
- `/Users/sdpaik/dev/cartly/build/ios/ipa/Cartly.ipa`

### 4) 업로드
현재 실제 사용한 경로는 `xcrun altool` 기반 업로드다.
업로드 후 delivery UUID를 기록한다.

### 5) App Store Connect 확인
최소 확인 항목:
- build status = `VALID`
- import status = `VALID`
- is on App Store Connect = `true`
- encryption = `false`

## 3. 현재 iOS / App Store Connect 기준 정보
- latest uploaded delivery UUID: `65b9c131-01e8-495f-86bf-762f0e6c5477`
- latest uploaded build line: `1.0.8 (18)`
- current live App Store version id: `a173b232-fe9b-4fdd-9557-a784bd7a36d2` (`1.0` / public live)
- historical submitted App Store version id used for the `1.0.8` release flow: `d2511728-acf2-4373-aea3-ccd45bb83a2c`
- historical submitted App Store version localization id: `facf2f69-6135-4355-9e2a-48dd2516f57c`
- App info localization id: `57760505-1949-4e93-b21c-9502891d493c`
- historical submitted App Store review detail id: `ad720b53-50fc-411e-96f2-0753b4dd3f3f`
- historical review submission id for the `1.0.8` release flow: `4802007b-99aa-45e2-a873-3c17ec61d84b`

### review contact
- email: `cartly.support@gmail.com`
- phone: `+82 10-9112-5123`
- name: `Seungdae Paik`

### metadata 기준
- display name: `카트리`
- subtitle: `장보기 기록과 대체안 탐색`
- privacy URL: `https://scan-api.seoa-nas.com/privacy`
- support URL: `https://scan-api.seoa-nas.com/support`
- marketing URL: `https://scan-api.seoa-nas.com/`

## 4. App Store screenshot 운영

### 실제 기준 폴더
- valid: `~/Desktop/Cartly-AppStore-Screenshots-v2`
- obsolete preview-based set: `~/Desktop/Cartly-AppStore-Screenshots`

### 현재 업로드된 display type
- iPhone: `APP_IPHONE_67`
- iPad: `APP_IPAD_PRO_3GEN_129`

### 원칙
- preview clone이 아니라 실제 최신 UI 기준이어야 한다.
- family share / member settings 같은 최근 UI가 반영되어야 한다.
- 2026-05-29 release decision: screenshot refresh is deferred to the next app version, so the `1.0.8` submission intentionally reuses the current screenshot set.

## 5. Apple API 자동화 기록

### 왜 중요하나
Cartly는 단순 수동 클릭이 아니라 **App Store Connect API를 붙여 metadata와 screenshots를 자동 갱신한 경험**이 이미 있다.
이 흐름은 반드시 release 문서에 남겨야 한다.

### 현재 인증 정보
- key path: `~/.appstoreconnect/private_keys/AuthKey_32X2GPDX2Y.p8`
- key id: `32X2GPDX2Y`
- issuer id: `5bd6df42-90f8-4aec-99af-08c41eb0bf7a`
- JWT alg: `ES256`

### 실제 사용한 자동화 스크립트 성격
현재 repo 정식 스크립트가 아니라 임시 운영 스크립트로 사용한 파일들:
- `/tmp/cartly_patch_asc_metadata_v2.py`
- `/tmp/cartly_upload_screenshots.py`
- `/tmp/cartly_patch_keywords.py`

이 스크립트들이 한 일:
1. App Store Connect JWT 생성
2. app info localization patch
3. app store version localization patch
4. review detail create/patch
5. screenshot set 삭제/재생성/업로드/commit
6. uploaded asset state가 `COMPLETE` 될 때까지 polling
7. build를 target App Store version에 연결하는 API patch까지 수행 가능한 구조를 이미 검증함
8. `reviewSubmissions` 3-step flow(create submission -> add reviewSubmissionItem -> patch `submitted: true`)로 실배포 review submission까지 API로 진행 가능한 것을 검증함

### metadata automation이 다룬 항목
- app name
- subtitle
- privacy policy URL
- Korean description
- keywords
- marketing URL
- support URL
- App Review notes
- review contact email/phone/name
- current App Store version과 build relationship

### screenshot automation이 다룬 항목
- 기존 screenshot set purge
- 새 screenshot set 생성
- upload reservation
- chunk upload
- checksum commit
- completion polling
- iPad용 업로드 시 필요한 리사이즈 처리 (`2048x2732`)

### 개선 권고
현재 `/tmp` 스크립트는 durable하지 않다.
향후에는 repo 안 `scripts/release/`로 옮겨 정식화하는 것이 좋다.
하지만 **이미 API 자동화가 가능하다는 사실 자체는 release 시스템의 일부로 간주**한다.

## 6. iOS review readiness 체크리스트
코드/제품 기준 완료된 것:
- guest mode 있음
- in-app account deletion 있음
- privacy policy in-app 진입 있음
- public privacy/support URL 있음
- foreground-only location 사용
- `NSLocationAlwaysAndWhenInUseUsageDescription` 제거 완료
- `ITSAppUsesNonExemptEncryption = false`

현재 상태:
- 2026-05-20 morning 기준 iOS public release는 App Store에 live 상태다.
- direct App Store URL은 immediately usable 하지만, App Store search / web indexing 반영은 잠시 지연될 수 있다.
- 출시 직후 홍보는 검색 유도보다 direct App Store URL 공유를 우선한다.
- 2026-05-20 night 기준 `1.0.6 (7)` 업로드까지 완료되었고, delivery UUID는 `9fac0cc3-5b5e-4afc-8f5c-7dc72218007c` 이다. 이 빌드에는 family-share/logout current-cart default fix, first-launch guest bootstrap + authenticated `app_open` tracking, and the iOS location-permission review-warning mitigation pass가 포함된다.
- 2026-05-21 early-morning 기준 `1.0.6 (8)` 업로드까지 완료되었고, delivery UUID는 `d176d4a8-f775-4a2e-8edd-47b518873c3c` 이다. 이 빌드에는 Explore에서 필터된 Naver Shopping 결과를 바로 보여주는 현재 정책이 반영된다.
- 2026-05-21 later 기준 `1.0.6 (9)` 업로드까지 완료되었고, delivery UUID는 `28566327-afb0-48c3-9951-11b8b099dbe9` 이다. 이 빌드에는 scan state persistence fix, Explore detail Naver-result rendering fix, fake store-promo suppression, and the Explore duplicate-structure cleanup pass가 함께 포함된다.
- 2026-05-21 production submission pass 기준 먼저 `1.0.6 (10)` 업로드와 review submission 까지 완료했지만, Apple이 그 라인을 이미 승인 완료된 version 보다 낮거나 같은 marketing version 으로 간주해 이후 추가 업로드에서 `90062` / closed pre-release train `90186` 을 반환했다.
- 그 결과 실제 다음 제출 라인은 `1.0.7` 로 올리는 것으로 확정했고, 먼저 `1.0.7 (13)` 업로드와 attach/review submission 까지 완료되었다. delivery UUID는 `afcab324-a22a-48d9-8d80-e34b66056e52` 이다.
- 이어서 Explore app-side follow-up fix를 반영한 `1.0.7 (14)` IPA 빌드와 업로드도 완료되었다. delivery UUID는 `3b276e1e-12c4-4404-8fd8-824d7a1b89db` 이다.
- 새 `1.0.7 (14)` 빌드에는 ranked single-pool recommendation surface, admin-curated plus search alternative blending, Flutter-side full-banner promo rendering alignment, 기존 Explore cleanup/fix bundle, current-cart default correction, iOS location-permission review-warning mitigation pass, 그리고 admin-truth Explore restoration/detail-cleanup follow-up이 포함된다.
- build `14` 는 App Store Connect processing `VALID` 까지 확인했고, 기존 `WAITING_FOR_REVIEW` 상태의 build `13` 제출을 `DELETE /v1/appStoreVersionSubmissions/{id}` 로 회수한 뒤 build relationship을 `14` 로 교체했다.
- 이후 follow-up validation builds `15`, `16`, `17` 도 순차 업로드되었고, 최종적으로 build `17` (`e5fb66ce-38b8-4b11-b3b8-4cb08bfe0d4b`) 가 `VALID` 인 것을 확인했다.
- 2026-05-22 기준 App Store version `1.0.7` 이 일시적으로 `DEVELOPER_REJECTED` 상태였기 때문에 build relationship을 `17` 로 직접 교체한 뒤, `reviewSubmissions` API flow(create submission -> add reviewSubmissionItem -> patch reviewSubmission `submitted: true`)로 새 review submission `0cbf5fe0-8c67-4732-932f-523bcb788301` 를 생성했다.
- 이후 Apple이 `1.0.7` pre-release train 에 새 업로드를 더 받지 않아 `90062` / closed train `90186` 를 반환했고, 실제 fix release line은 `1.0.8` 로 올리는 것으로 확정되었다.
- `1.0.8 (18)` IPA 빌드와 업로드도 완료되었고, delivery UUID는 `65b9c131-01e8-495f-86bf-762f0e6c5477` 이다.
- `1.0.8` App Store version `d2511728-acf2-4373-aea3-ccd45bb83a2c` 를 새로 만들고, build relationship을 `18` 로 연결한 뒤, Korean `What's New` 와 review notes를 현재 scan reliability fix 기준으로 갱신했다.
- `reviewSubmissions` 3-step flow를 다시 실행해 review submission `4802007b-99aa-45e2-a873-3c17ec61d84b` 를 만들고 제출까지 완료했다.
- 이후 공개 App Store 조회 기준으로 `1.0.8` 이 실제 live 상태임이 확인되었으므로, 위 review-submission ids 는 현재 상태가 아니라 release automation history 로 취급한다.

## 7. Android / Google Play release 흐름

### package / artifact
- package id: `com.seungdae.cartly`
- Android AdMob app ID: `ca-app-pub-7326648056182385~9903617195`
- release AAB: `/Users/sdpaik/dev/cartly/build/app/outputs/bundle/release/app-release.aab`
- default Android release policy: **internal testing track first**, then iOS/Android eye review, then dual-platform final submission

### 빌드 스크립트
```bash
/Users/sdpaik/dev/cartly/scripts/build-android-play-release.sh
```

역할:
- `android/key.properties` 존재 확인
- `flutter build appbundle --release`
- `jarsigner` verify
- `keytool -list -v`로 keystore 검증 정보 출력

추가 규칙:
- Android는 Play 업로드용 `versionCode` 를 되돌릴 수 없으므로, 필요하면 `CARTLY_ANDROID_VERSION_CODE=<증가값>` 환경변수로 업로드 코드만 별도 override 한다.
- 2026-05-19 `1.0.5` 리셋 라인 Android AAB는 Play 증가 제약에 맞춰 최신 준비 값 `CARTLY_ANDROID_VERSION_CODE=33` 로 다시 빌드했다.
- 2026-05-20 night 기준 최신 Android release verification build는 `CARTLY_ANDROID_VERSION_CODE=40` 로 다시 통과했고, customer-facing versionName 은 `1.0.6` 이다.
- 2026-05-21 early-morning 기준 최신 Android release verification build는 `CARTLY_ANDROID_VERSION_CODE=41` 로 다시 통과했고, customer-facing versionName 은 `1.0.6` 이다.
- 2026-05-21 later 기준 최신 Android release verification build는 `CARTLY_ANDROID_VERSION_CODE=42` 로 다시 통과했고, customer-facing versionName 은 `1.0.6` 이다.
- 2026-05-21 morning follow-up 기준 Android regression-fix tester build는 `CARTLY_ANDROID_VERSION_CODE=43` 으로 다시 통과했고, customer-facing versionName 은 `1.0.6` 이다.
- 2026-05-21 afternoon release follow-up 기준 next release wave build는 `CARTLY_ANDROID_VERSION_CODE=44` 로 다시 통과했고, customer-facing versionName 은 `1.0.7` 이다.
- 같은 날 evening follow-up 기준 Explore admin-truth restoration/detail-cleanup wave build는 `CARTLY_ANDROID_VERSION_CODE=45` 로 다시 통과했고, customer-facing versionName 은 `1.0.7` 이다.
- 2026-05-22 morning follow-up 기준 auth-backed Explore-offer fetch/customer-update wave build는 `CARTLY_ANDROID_VERSION_CODE=46` 으로 다시 통과했고, customer-facing versionName 은 `1.0.7` 이다.

### Play internal upload 스크립트
```bash
PLAY_VERSION_NAME=1.0.5 \
PLAY_RELEASE_NAME='1.0.5 (33)' \
/Users/sdpaik/dev/cartly/scripts/upload-android-play-internal.rb
```

역할:
- service account JWT 로 Android Publisher access token 발급
- edit 생성
- release AAB 업로드
- `internal` track release 반영
- edit commit

주의:
- 이 스크립트는 **Play Console 에 권한이 연결된 전용 service account JSON** 이 필요하다.
- 기본 탐색 경로는 `~/Library/Application Support/Cartly/play/cartly-play-api.json` 이다. 다른 위치를 쓰려면 `PLAY_SERVICE_ACCOUNT_JSON=/path/to/file.json` 으로 override 한다.
- 2026-05-19 기준 실제 작동이 확인된 전용 키는 `cartly-play-api@cartly-e36ee.iam.gserviceaccount.com` 이며, NAS 마운트 경로 `/Volumes/downloads/cartly-e36ee-dcb07ec17251.json` 에 있던 파일을 표준 경로 `~/Library/Application Support/Cartly/play/cartly-play-api.json` 로 복사해 로컬 기본 경로도 복구했다.
- 현재 로컬에서 확인된 Firebase admin JSON 은 token 발급은 되지만 Android Publisher 권한이 없어 `403 PERMISSION_DENIED` 를 반환했다.

### signing 구조
- local keystore: `~/Library/Application Support/Cartly/android-release/cartly-upload-key.jks`
- local note: `~/Library/Application Support/Cartly/android-release/keystore-info.txt`
- local config: `android/key.properties` (repo 미커밋 유지)

### 현재 서명 정보
- alias: `cartlyupload`
- signer: `CN=Seungdae Paik, OU=Cartly, O=Cartly, L=Seoul, ST=Seoul, C=KR`
- SHA1: `8E:98:D2:62:DC:4A:50:73:75:BB:B9:45:78:94:2D:51:5B:9F:CF:32`
- SHA256: `7F:A5:4B:B0:8E:E8:7D:F1:AA:96:BA:5F:4F:0B:9D:FC:B2:60:A7:E7:E6:79:12:FB:0B:07:4A:87:F4:0D:31:21`

### Android Publisher API 연결 상태
- Google Cloud project: `cartly-e36ee`
- service account email: `cartly-play-api@cartly-e36ee.iam.gserviceaccount.com`
- Google Play Android Developer API enabled 확인 완료
- Play Console `사용자 및 권한`에 service account 활성 연결 완료
- 2026-05-18 기준 Android Publisher API로 edit 생성 및 internal track upload/commit 성공
- 2026-05-19 기준 NAS에 있던 동일 service-account JSON으로 `1.0.5 (34)` internal track upload/commit 재성공, 이후 표준 경로 `~/Library/Application Support/Cartly/play/cartly-play-api.json` 도 복구 완료
- 2026-05-20 night 기준 같은 service-account 경로로 Android internal track 업로드를 다시 실행했고, `1.0.6 (40)` releaseName 으로 upload/commit 성공했다.
- 같은 night 기준 closed-test 쪽 alpha track 도 기존 build `39` 에서 `1.0.6 (40)` 로 맞췄다. 이미 등록된 versionCode `40` 을 재업로드하지 않고 track release update 로 연결했다.
- 2026-05-21 early-morning 기준 같은 service-account 경로로 Android internal track에 `1.0.6 (41)` upload/commit 성공했다.
- 같은 시점 기준 alpha track 도 기존 build `40` 에서 `1.0.6 (41)` 로 다시 맞췄다. 이미 업로드된 versionCode `41` 을 alpha release update 로 연결했다.
- 2026-05-21 later 기준 같은 service-account 경로로 Android internal track에 versionCode `42` upload/commit 성공했다. 첫 upload 결과의 release name 은 스크립트 env 누락으로 `1.0.5 (42)` 로 들어갔지만, 같은 날 internal/alpha track release를 모두 `1.0.6 (42)` 로 즉시 정정했다.
- 2026-05-21 afternoon release follow-up 기준 같은 service-account 경로로 Android internal track에 `1.0.7 (44)` upload/commit 성공했다.
- 같은 시점 기준 alpha track 도 이미 업로드된 versionCode `44` 를 release update 로 연결해 `1.0.7 (44)` 로 정렬했다.
- 2026-05-21 evening Explore follow-up 기준 같은 service-account 경로로 Android internal track에 `1.0.7 (45)` upload/commit 성공했다.
- 같은 시점 기준 alpha track 도 이미 업로드된 versionCode `45` 를 release update 로 연결해 `1.0.7 (45)` 로 정렬했다.
- 2026-05-21 morning regression-fix follow-up 기준 같은 service-account 경로로 Android internal track에 versionCode `43` upload/commit 성공했다. 이후 alpha track은 이미 업로드된 동일 versionCode `43` 을 재업로드하지 않고 track release update 로 연결해 `1.0.6 (43)` 으로 맞췄다.
- 2026-05-22 morning follow-up 기준 같은 service-account 경로로 Android internal track에 `1.0.7 (46)` upload/commit 성공했다.
- 같은 시점 기준 alpha track 도 이미 업로드된 versionCode `46` 을 release update 로 연결해 `1.0.7 (46)` 로 정렬했다.
- internal track release:
  - track: `internal`
  - build/versionCode: `46`
  - release name: `1.0.7 (46)`
- closed-test track release:
  - track: `alpha`
  - build/versionCode: `46`
  - release name: `1.0.7 (46)`

## 8. Google Play Console 현재 상태
- 개발자 계정 signup 및 console verification 완료
- proof-of-address 제출/검증 단계는 지난 상태이며, 이제 운영 문맥에서는 완료된 것으로 본다.
- Android spare device 확보 및 verification 대응 문맥도 지나갔다.
- 현재 기준 관심사는 **실제 app creation / listing / AAB upload / track submission / review 대응 운영**이다.

### 현재 원칙
- 이제 Android도 완전 수동-only가 아니다.
- build/signing은 로컬 스크립트로, Play 업로드/track 반영은 service account + Android Publisher API로 자동화할 수 있다.
- 다만 listing/data safety/content rating/app access/review questionnaire는 여전히 콘솔 운영이 필요하다.
- 문서와 체크리스트도 이제 “인증 준비”가 아니라 “실출시 운영” 기준으로 유지한다.
- 2026-05-18 기준 Android startup blocker였던 AdMob application ID는 AdMob 콘솔 앱 설정에서 실제 값 `ca-app-pub-7326648056182385~9903617195` 로 확인되었고, review/release 빌드는 더 이상 test app ID에 의존하지 않는다.
- 같은 날 Android release smoke에서 `flutter_local_notifications` 의 receipt reminder cancel 경로가 startup 직후 `Missing type parameter` 예외를 만들 수 있음이 확인되었고, `ShoppingNudgeService` 에 Android 방어 처리를 넣은 뒤 release APK 재설치/재실행 기준으로 `MainActivity` resumed, `MobileAdsInitProvider` crash 없음, final startup logcat clean 상태까지 다시 검증했다.
- 같은 날 최종 release 표면 점검에서 iOS/Android/live runtime/public web/customer-facing support/version 값이 다시 교차 확인되었고, admin `app-preview` fallback 탭 라벨도 `홈 / 탐색 / 마이페이지` 기준으로 재빌드해 맞췄다.
- 같은 날 이어진 마지막 교차 점검에서 live runtime은 `my.pageTitle = 마이페이지` 로 이미 정렬되어 있었지만 preview/mock 기본값 일부가 아직 `마이` 로 남아 있는 drift가 한 번 더 발견되었다. `admin-web/lib/mock.ts`, `lib/preview_main.dart`, 재생성된 `admin-web/public/app-preview/main.dart.js` 까지 다시 맞춰 preview에서도 `마이페이지` 기준이 유지되도록 정리했다.
- 같은 날 lower-priority 공개 웹 polish로 `scripts/public-site/site.css` 의 파란 톤 기본 팔레트를 Cartly red + warm neutral 계열로 조정해 앱 브랜드와 공개 웹의 첫인상 색감이 더 가깝게 맞도록 정리했다.

## 9. Google Play 제출 체크리스트
- app 생성
- Play App Signing / upload key 수락
- store listing 텍스트/이미지
- Data safety
- Content rating
- App access
- AAB 업로드
- internal testing 또는 production track 생성

## 10. release commit 규칙
권장 흐름:
1. 기능 커밋
2. 버전 bump commit
3. build/upload
4. delivery/build id 기록
5. 필요 시 metadata/screenshots API patch

## 11. 지금 release에서 놓치면 안 되는 것
- Apple API 기반 metadata/screenshot patch 경험이 이미 있으므로, 이후 수동 클릭만으로 회귀하지 않는다.
- Google Play는 이제 “인증 전 준비” 단계가 아니라 “실제 배포 운영” 단계로 옮겨가야 한다.
- iOS와 Android 모두 build artifact뿐 아니라 store console 상태를 함께 기록해야 한다.

## 12. 다음 release 작업
1. iOS `1.0.7 (17)` App Store review 상태를 추적하고, Apple follow-up 질문이 오면 같은 wave 안에서 바로 응답한다.
2. Android는 production upload/release 버튼을 다시 누르기 전에, Google Play personal-account gate를 먼저 해소한다. closed-test binary line 은 now `alpha = 1.0.7 (46)` 로 맞췄고, 현재 필요한 것은 12명 이상의 opted-in tester 확보와 14일 유지다.
3. Android closed-test 기간 동안 Play listing high-res icon / store 표면이 generic 하게 보이면 listing metadata 쪽을 계속 정리한다.
4. 향후 production access가 열리면 그때 existing `1.0.7` release line 기준으로 Android production/review submission을 재개한다.
5. 다음 paired public-release wave를 다시 맞출 때는 iOS 승인 상태와 Android closed-test eligibility 상태를 함께 본다.

## 13. 2026-05-19 검수 마감 UI 체크포인트
### 확정된 탐색 / 장보기 헤더 규칙
- Home 과 Explore 는 상단 헤더 리듬과 하단 여백이 같이 흔들리지 않도록 같은 문법을 유지한다.
- Explore 에서 shopping mode 가 활성화되면 red header band 는 상태바 아래까지 이어지는 immersive block 으로 보인다.
- red band 는 floating card 처럼 보이면 안 되고, background block 이 더 아래로 내려온 상태여야 한다.
- 헤더 텍스트와 우상단 mode toggle 아이콘 위치는 유지하고, 배경 블록 높이만 조정한다.
- body 는 bottom SafeArea 로 인해 탭 전환 때 높이가 흔들리지 않도록 관리한다.

### 현재 검수 기준값
- working source version: `1.0.7+13`
- latest iOS review build: `1.0.7 (13)`
- latest Android internal-testing build: `1.0.7 (44)`
- support email baseline: `cartly.support@gmail.com`
- customer-facing Explore wording baseline: `탐색`

### 최종 제출 전 5분 체크리스트
#### A. 빌드 / 앱 표면
- `pubspec.yaml` 버전이 `1.0.7+13` 인지 확인
- iOS `CFBundleDisplayName = Cartly` 확인
- Android `android:label = Cartly` 확인
- Android launcher icon 이 iOS와 같은 cart icon 기준으로 정렬되었는지 확인
- native launch / Flutter splash 기본 자산이 모두 cart-pushing photo 기준인지 확인
- Android merged manifest에 `android:versionCode="44"`, `android:versionName="1.0.7"`, AdMob app ID `ca-app-pub-7326648056182385~9903617195` 가 들어 있는지 확인
- 최근 smoke 기준 Android startup crash, asset load crash, notification startup exception이 다시 재발하지 않았는지 확인

#### B. 런타임 / 고객-facing copy
- `/v1/app-config` 에서 `help.pageTitle = 탐색` 확인
- `/v1/app-config` 에서 `my.supportEmail = cartly.support@gmail.com` 확인
- `/v1/app-config` 에서 public eyebrow/version 값이 최신 검수 빌드 라인과 맞는지 확인
- branding 값에서 `logoType = image`, live Cartly SVG `logoImageUrl`, expected `splashImageUrl` 를 확인
- release 검증 시 app startup 이 `https://scan-api.seoa-nas.com` 기준 runtime/admin surface 를 바라보는지 확인하고, local backend access log 는 Cloudflare/Tunnel 경유 public hit 로도 찍힐 수 있다는 점을 감안해 함께 판단

#### C. 공개 웹
- `/` title 이 `Cartly | 장보기 기록과 대체안 탐색` 인지 확인
- `/privacy` title 이 `Cartly | 개인정보 안내` 인지 확인
- `/support` title 이 `Cartly | 지원 안내` 인지 확인
- `/`, `/privacy`, `/support` 어디에서도 support/business/version 문구 drift 가 없는지 확인
- support email `cartly.support@gmail.com`, business email `gabriel.paik@gmail.com` 가 일관적인지 확인

#### D. admin preview / fallback
- preview fallback tab labels 가 `홈 / 탐색 / 마이페이지` 인지 확인
- preview/default `myPageTitle` 이 더 이상 `마이` 로 남아 있지 않고 `마이페이지` 인지 확인
- regenerated `admin-web/public/app-preview/main.dart.js` 가 최신 preview defaults 를 반영했는지 확인

#### E. store console 마지막 인간 체크
- iOS: Age Rating, App Privacy questionnaire, review contact, privacy/support URL, screenshots 최종 확인 후 review submission 완료 여부 확인
- Android: store listing, Data safety, Content rating, App access, internal/prod track release note 최종 확인 + closed test gate(12 testers / 14 days) 상태 확인
- 두 플랫폼 모두 동일한 customer-facing naming/copy 로 보이는지 마지막 눈검수

### 제출 판단 규칙
- A~D 중 하나라도 drift 가 보이면 제출 전에 먼저 고친다.
- iOS는 A~D 가 깨끗하고 store questionnaire가 끝나면 review submission까지 진행한다.
- Android는 A~D/E 가 깨끗해도, Play closed-test gate(12 testers / 14 days)가 풀리기 전에는 production submission이 막힐 수 있음을 전제로 운영한다.

## Related notes
- [[01_brand/brand-system]]
- [[05_web/web-service]]
- [[06_infra/infra-system]]
