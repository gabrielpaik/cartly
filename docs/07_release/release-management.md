# Cartly Release Management

Last updated: 2026-05-18
Status: canonical
Purpose: release operations contract for iOS, TestFlight, App Store Connect, and Google Play
Use this doc when: building, uploading, patching store metadata, or preparing submission/review steps

## 1. release 운영 원칙

### 기본 규칙
- 릴리즈용 앱 빌드를 만들기 전에 **반드시 build number를 먼저 올린다**.
- 사용자가 명시적으로 멈추라고 하지 않는 한, **성공한 iOS 빌드는 TestFlight/App Store Connect 업로드까지 이어간다**.
- release 변경은 가능하면 별도 release commit으로 남긴다.
- 스크린샷/메타데이터/리뷰 노트까지 같이 관리해야 진짜 release readiness다.

### 현재 기준 버전
- current app version/build: `1.0.4+26`
- latest shipped iOS build label: `1.0.4 (26)`

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
- latest delivery UUID: `fcc14698-3433-4fd6-9a79-402dfebc0508`
- current App Store version id: `a173b232-fe9b-4fdd-9557-a784bd7a36d2`
- App Store version localization id: `64db26e7-c8a0-480e-9b9f-fb06c78a1ad5`
- App info localization id: `57760505-1949-4e93-b21c-9502891d493c`
- App Store review detail id: `784f5c12-b1f5-4651-bbd6-812255bb6fb5`

### review contact
- email: `scancart.wimc@gmail.com`
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
7. build를 current App Store version에 연결하는 API patch까지 수행 가능한 구조를 이미 검증함

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

남은 console 작업:
- Age Rating
- App Privacy questionnaire 최종 확인
- 최종 Submit for Review

## 7. Android / Google Play release 흐름

### package / artifact
- package id: `com.seungdae.cartly`
- release AAB: `/Users/sdpaik/dev/cartly/build/app/outputs/bundle/release/app-release.aab`

### 빌드 스크립트
```bash
/Users/sdpaik/dev/cartly/scripts/build-android-play-release.sh
```

역할:
- `android/key.properties` 존재 확인
- `flutter build appbundle --release`
- `jarsigner` verify
- `keytool -list -v`로 keystore 검증 정보 출력

### signing 구조
- local keystore: `~/Library/Application Support/Cartly/android-release/cartly-upload-key.jks`
- local note: `~/Library/Application Support/Cartly/android-release/keystore-info.txt`
- local config: `android/key.properties` (repo 미커밋 유지)

### 현재 서명 정보
- alias: `cartlyupload`
- signer: `CN=Seungdae Paik, OU=Cartly, O=Cartly, L=Seoul, ST=Seoul, C=KR`
- SHA1: `8E:98:D2:62:DC:4A:50:73:75:BB:B9:45:78:94:2D:51:5B:9F:CF:32`
- SHA256: `7F:A5:4B:B0:8E:E8:7D:F1:AA:96:BA:5F:4F:0B:9D:FC:B2:60:A7:E7:E6:79:12:FB:0B:07:4A:87:F4:0D:31:21`

## 8. Google Play Console 현재 상태
- 개발자 계정 signup 및 console verification 완료
- proof-of-address 제출/검증 단계는 지난 상태이며, 이제 운영 문맥에서는 완료된 것으로 본다.
- Android spare device 확보 및 verification 대응 문맥도 지나갔다.
- 현재 기준 관심사는 **실제 app creation / listing / AAB upload / track submission / review 대응 운영**이다.

### 현재 원칙
- Play Console은 아직 repo 내부 API 자동화가 없다.
- 즉, Android는 build/signing은 로컬 자동화, console 제출은 수동 운영이 기본이다.
- 문서와 체크리스트도 이제 “인증 준비”가 아니라 “실출시 운영” 기준으로 유지한다.

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
1. 상단 로고 fallback이 반영된 다음 iOS build 업로드
2. 필요 시 App Store screenshot 재캡처
3. Age Rating / App Privacy / Submit for Review 완료
4. Google Play app creation, AAB 업로드, listing/review 질문 답변 정리
5. Apple metadata/screenshot automation 스크립트를 repo 안 `scripts/release/`로 승격할지 결정

## Related notes
- [[01_brand/brand-system]]
- [[05_web/web-service]]
- [[06_infra/infra-system]]
