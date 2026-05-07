# CARTLY_ICON_INVENTORY

기준 시점: 2026-05-07

이 문서는 현재 Cartly에서 아이콘/브랜드 이미지가 어디에 쓰이는지 정리한 인벤토리다.
다음 패스에서 새 아이콘 파일을 받을 때, 이 문서의 `권장 파일명` 기준으로 맞춰 받으면 바로 교체 작업을 이어갈 수 있다.

## 1. 현재 아이콘 소스 구조

Cartly의 아이콘/이미지 소스는 지금 3종류다.

1. **플랫폼 런처 아이콘**
   - iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/*`
   - Android: `android/app/src/main/res/mipmap-*/ic_launcher.png`

2. **브랜드/화면용 이미지**
   - 스플래시 fallback: `assets/images/intro.png`
   - admin 업로드 URL 기반:
     - `logoImageUrl`
     - `splashImageUrl`
     - `loginHeroImageUrl`

3. **앱 내부 UI 아이콘**
   - 대부분 Flutter `Icons.*` 머티리얼 아이콘을 직접 사용 중
   - 즉, 지금은 파일 기반 커스텀 아이콘 세트가 아직 없음

## 2. 우선순위가 높은 교체 대상

사용자 피드백 기준으로, 다음 순서로 교체하는 게 효율적이다.

1. 하단 네비게이션 아이콘 3종
2. 홈 / 탐색 / 마이의 대표 아이콘
3. 현재 카트 / 지난 카트 / 상세 / 영수증 비교 액션 아이콘
4. 런처 아이콘, 스플래시, 로고

## 3. 플랫폼 런처 아이콘

### iOS AppIcon 세트

경로: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

| 현재 파일명 | 실제 크기 | 용도 |
|---|---:|---|
| `Icon-App-20x20@1x.png` | 20x20 | iPad notification |
| `Icon-App-20x20@2x.png` | 40x40 | iPhone/iPad notification |
| `Icon-App-20x20@3x.png` | 60x60 | iPhone notification |
| `Icon-App-29x29@1x.png` | 29x29 | settings |
| `Icon-App-29x29@2x.png` | 58x58 | settings |
| `Icon-App-29x29@3x.png` | 87x87 | settings |
| `Icon-App-40x40@1x.png` | 40x40 | iPad spotlight |
| `Icon-App-40x40@2x.png` | 80x80 | spotlight |
| `Icon-App-40x40@3x.png` | 120x120 | spotlight |
| `Icon-App-60x60@2x.png` | 120x120 | iPhone home |
| `Icon-App-60x60@3x.png` | 180x180 | iPhone home |
| `Icon-App-76x76@1x.png` | 76x76 | iPad home |
| `Icon-App-76x76@2x.png` | 152x152 | iPad home |
| `Icon-App-83.5x83.5@2x.png` | 167x167 | iPad Pro |
| `Icon-App-1024x1024@1x.png` | 1024x1024 | App Store marketing |

### Android launcher 세트

경로: `android/app/src/main/res/mipmap-*/ic_launcher.png`

| 현재 파일명 | 실제 크기 | 용도 |
|---|---:|---|
| `mipmap-mdpi/ic_launcher.png` | 48x48 | Android launcher |
| `mipmap-hdpi/ic_launcher.png` | 72x72 | Android launcher |
| `mipmap-xhdpi/ic_launcher.png` | 96x96 | Android launcher |
| `mipmap-xxhdpi/ic_launcher.png` | 144x144 | Android launcher |
| `mipmap-xxxhdpi/ic_launcher.png` | 192x192 | Android launcher |

### 알림 아이콘 관련

- `lib/services/shopping_nudge_service.dart`
  - Android local notification 초기화에 `@mipmap/ic_launcher` 사용 중
- 즉, 런처 아이콘 교체 시 **알림 아이콘 인상도 같이 바뀔 수 있음**

## 4. 브랜드 / 화면 이미지

### 4-1. 앱 로고

| 현재 소스 | 사용 위치 | 코드 | 비고 | 권장 파일명 |
|---|---|---|---|---|
| admin 업로드 `logoImageUrl` | drawer 상단 브랜드 마크 | `lib/widgets/brand_mark.dart`, `lib/widgets/cartly_end_drawer.dart` | `logoType=image/text_image`일 때 이미지 사용 | `brand-logo.png` |
| 텍스트 로고 fallback | 동일 | `BrandMark` | 현재는 `SpaceGrotesk` 텍스트 fallback | 없음 |

### 4-2. 스플래시 이미지

| 현재 소스 | 사용 위치 | 코드 | 비고 | 권장 파일명 |
|---|---|---|---|---|
| admin 업로드 `splashImageUrl` | 앱 시작 splash | `lib/splash_screen.dart` | URL 있으면 우선 사용 | `splash-image.png` |
| `assets/images/intro.png` | splash fallback | `lib/splash_screen.dart` | 현재 기본 fallback, 1440x2560 | `assets/images/intro.png` |

### 4-3. 로그인 hero 이미지

| 현재 소스 | 사용 위치 | 코드 | 비고 | 권장 파일명 |
|---|---|---|---|---|
| admin 업로드 `loginHeroImageUrl` | 로그인 상단 hero | `lib/widgets/login_page_header_section.dart` | 없으면 이미지 없이 텍스트만 표시 | `login-hero.png` |

### 4-4. iOS LaunchImage 세트

경로: `ios/Runner/Assets.xcassets/LaunchImage.imageset/`

| 현재 파일명 | 실제 크기 | 비고 |
|---|---:|---|
| `LaunchImage.png` | 200x200 | 기본 iOS launch asset |
| `LaunchImage@2x.png` | 400x400 | 기본 iOS launch asset |
| `LaunchImage@3x.png` | 600x600 | 기본 iOS launch asset |

참고:
- 실제 체감 splash는 Flutter `SplashScreen` 쪽이 더 중요함
- iOS LaunchImage는 앱 초기 부팅 순간용 보조 자산으로 보면 됨

## 5. 앱 내부 UI 아이콘 인벤토리

아래는 실제 앱 코드 기준 인벤토리다.

### 5-1. 하단 네비게이션

파일: `lib/pages/home_page.dart`

| 위치 | 현재 아이콘 | 상태 | 권장 파일명 |
|---|---|---|---|
| 홈 탭 | `Icons.home_outlined` / `Icons.home` | 기본 / 선택 | `nav-home-outline.svg`, `nav-home-filled.svg` |
| 탐색 탭 | `Icons.explore_outlined` / `Icons.explore` | 기본 / 선택 | `nav-explore-outline.svg`, `nav-explore-filled.svg` |
| 마이 탭 | `Icons.person_outline` / `Icons.person` | 기본 / 선택 | `nav-my-outline.svg`, `nav-my-filled.svg` |

### 5-2. 홈 화면

#### 현재 카트 섹션
파일: `lib/widgets/current_cart_section.dart`

| 위치 | 현재 아이콘 | 의미 | 권장 파일명 |
|---|---|---|---|
| empty state | `Icons.shopping_cart_outlined` | 현재 카트 비어있음 | `home-current-cart-empty.svg` |
| swipe delete | `Icons.delete_outline_rounded` | 현재 카트 아이템 삭제 | `home-current-cart-delete.svg` |
| 펼침 상태 | `Icons.keyboard_arrow_up_rounded` | 편집 영역 닫기 | `home-current-cart-collapse.svg` |
| 접힘 상태 | `Icons.keyboard_arrow_down_rounded` | 편집 영역 열기 | `home-current-cart-expand.svg` |
| 수량 감소 | `Icons.remove_rounded` | 수량 -1 | `qty-minus.svg` |
| 수량 증가 | `Icons.add_rounded` | 수량 +1 | `qty-plus.svg` |

#### 새 상품 추가 / 최근 스캔
파일: `lib/widgets/item_add_section.dart`

| 위치 | 현재 아이콘 | 의미 | 권장 파일명 |
|---|---|---|---|
| 가격표 인식하기 | `Icons.camera_alt` | OCR 촬영/인식 진입 | `home-add-scan.svg` |
| 직접 추가하기 | `Icons.edit` | 수동 입력 진입 | `home-add-manual.svg` |
| 최근 스캔 row 이동 | `Icons.chevron_right` | 상세/재확인 진입 | `list-chevron-right.svg` |
| 최근 스캔 지우기 | `Icons.close` | 최근 스캔 dismiss | `close-small.svg` |

#### 홈 하단 Explore 유도 타일
파일: `lib/pages/home_tab_view.dart`

| 위치 | 현재 아이콘 | 의미 | 권장 파일명 |
|---|---|---|---|
| Explore teaser | `Icons.explore_outlined` | 탐색 탭으로 이동 | `home-explore-teaser.svg` |

### 5-3. 마이 / 지난 카트

#### 마이 상단 계정 카드
파일: `lib/pages/my_page.dart`

| 위치 | 현재 아이콘 | 의미 | 권장 파일명 |
|---|---|---|---|
| 회원 상태 | `Icons.history_toggle_off_rounded` | 회원/기록 중심 상태 아이콘 | `my-member-badge.svg` |
| 게스트 상태 | `Icons.shopping_bag_outlined` | 게스트 장보기 상태 아이콘 | `my-guest-badge.svg` |
| 혜택/체크 칩 | `Icons.check_rounded` | benefit check mark | `check-small.svg` |

#### 지난 카트 목록
파일: `lib/widgets/saved_tab_empty_state.dart`, `lib/widgets/saved_cart_list_card.dart`, `lib/widgets/saved_tab_list_entry.dart`

| 위치 | 현재 아이콘 | 의미 | 권장 파일명 |
|---|---|---|---|
| empty state | `Icons.bookmark_border` | 저장된 카트 없음 | `saved-empty-bookmark.svg` |
| 카드 진입 | `Icons.chevron_right` | 지난 카트 상세 진입 | `list-chevron-right.svg` |
| swipe 삭제 | `Icons.delete_outline_rounded` | 저장 카트 삭제 | `saved-delete.svg` |

#### 저장 카트에서 다시 담기 영역
파일: `lib/widgets/saved_cart_item_add_section.dart`

| 위치 | 현재 아이콘 | 의미 | 권장 파일명 |
|---|---|---|---|
| 열기/닫기 | `Icons.add` / `Icons.close` | 추가 입력 열기/닫기 | `expand-add.svg`, `close-small.svg` |

### 5-4. 카트 상세

파일: `lib/widgets/cart_detail_item_tile.dart`, `lib/widgets/cart_detail_app_bar_actions.dart`, `lib/widgets/cart_detail_guest_retention_section.dart`, `lib/pages/cart_detail_page.dart`

| 위치 | 현재 아이콘 | 의미 | 권장 파일명 |
|---|---|---|---|
| item 수정 | `Icons.edit_outlined` | 상품명/가격 수정 | `detail-edit.svg` |
| item 삭제 | `Icons.close` | 상품 삭제 | `detail-delete-small.svg` |
| 수량 감소 | `Icons.remove_circle_outline` | 수량 -1 | `qty-minus-circle.svg` |
| 수량 증가 | `Icons.add_circle_outline` | 수량 +1 | `qty-plus-circle.svg` |
| 영수증 비교 없음 | `Icons.receipt_long_outlined` | 영수증 비교 진입 전 | `receipt-outline.svg` |
| 영수증 비교 있음 | `Icons.receipt_long` | 영수증 비교 진입 후/강조 | `receipt-filled.svg` |
| 상단 삭제 | `Icons.delete_outline` | 카트 전체 삭제 | `detail-delete.svg` |
| 게스트 리텐션 | `Icons.lock_outline_rounded` | 로그인 유도/잠금 | `detail-lock.svg` |
| 추가 이동/링크 row | `Icons.chevron_right` | 다음 화면 진입 | `list-chevron-right.svg` |

### 5-5. 탐색(Explore)

파일: `lib/pages/shopping_help_page.dart`, `lib/widgets/inline_promo_slot.dart`

| 위치 | 현재 아이콘 | 의미 | 권장 파일명 |
|---|---|---|---|
| 홈에서 장보기 시작/장보기 이어보기 CTA | `Icons.shopping_cart_checkout_rounded` | 장보기 시작 CTA | `explore-start-cart.svg` |
| 가린 대안 다시 보기 | `Icons.visibility_rounded` | 숨긴 대안 다시 보기 | `visibility-on.svg` |
| 추천/채택 표시 | `Icons.check_circle_outline_rounded` | 추천/선택 강조 | `explore-check.svg` |
| 지난 장보기 문맥 | `Icons.history_rounded` | 반복 구매/히스토리 | `explore-history.svg` |
| 숨김 처리 | `Icons.visibility_off_rounded` | 대안 숨기기 | `visibility-off.svg` |
| 홈 시작 fallback | `Icons.home_rounded` | 홈에서 다시 시작 | `explore-home.svg` |
| 최근 장보기 이어보기 | `Icons.shopping_bag_rounded` | 저장 카트 이어보기 | `explore-bag.svg` |
| 지난 카트 전체 보기 | `Icons.history_rounded` | 전체 히스토리 보기 | `explore-history.svg` |
| 외부 제휴 링크 | `Icons.open_in_new_rounded` | 외부 링크 이동 | `external-link.svg` |
| 인라인 프로모 오퍼 | `Icons.open_in_new` / `Icons.local_offer_outlined` | 클릭 가능 / 비클릭 혜택 | `external-link.svg`, `offer-tag.svg` |

### 5-6. 영수증 비교

파일: `lib/pages/receipt_comparison_page.dart`

| 위치 | 현재 아이콘 | 의미 | 권장 파일명 |
|---|---|---|---|
| 영수증 올리기 | `Icons.receipt_long_outlined` | 업로드 시작 | `receipt-upload.svg` |
| 원문 보기/숨기기 | `Icons.visibility_outlined` / `Icons.visibility_off_outlined` | raw text 토글 | `visibility-on.svg`, `visibility-off.svg` |
| 카메라 empty/placeholder | `Icons.camera_alt_outlined` | 촬영 유도 | `receipt-camera-outline.svg` |
| 갤러리 선택 | `Icons.photo_library_outlined` | 사진첩 업로드 | `receipt-gallery.svg` |
| 카메라 촬영 | `Icons.camera_alt` | 카메라 직접 촬영 | `receipt-camera-filled.svg` |

### 5-7. 완료 / 드로어 / 공통

파일: `lib/widgets/save_complete_bottom_sheet.dart`, `lib/widgets/cartly_end_drawer.dart`

| 위치 | 현재 아이콘 | 의미 | 권장 파일명 |
|---|---|---|---|
| 저장 완료 | `Icons.check_circle` | 저장 성공 | `success-check-circle.svg` |
| drawer row 진입 | `Icons.chevron_right` | 상세 페이지 이동 | `list-chevron-right.svg` |
| drawer 안내 | `Icons.info_outline` | 안내/설명 | `info-outline.svg` |

## 6. admin에서 연결된 이미지 필드

다음 3개는 admin에서 직접 바꿀 수 있는 이미지 필드다.

- `logoImageUrl`
- `splashImageUrl`
- `loginHeroImageUrl`

관련 파일:
- `admin-web/app/content/page.tsx`
- `admin-web/app/config/page.tsx`
- `lib/models/app_branding.dart`
- `lib/widgets/brand_mark.dart`
- `lib/splash_screen.dart`
- `lib/widgets/login_page_header_section.dart`

즉, 새 브랜딩 이미지 3종은 **파일만 받으면 업로드 후 바로 반영 가능한 상태**다.

## 7. 다음 패스에서 파일로 받으면 좋은 목록

아래는 내가 다음 작업 때 바로 받으면 좋은 권장 세트다.

### 필수 1차
- `nav-home-outline.svg`
- `nav-home-filled.svg`
- `nav-explore-outline.svg`
- `nav-explore-filled.svg`
- `nav-my-outline.svg`
- `nav-my-filled.svg`
- `brand-logo.png`
- `splash-image.png`
- `login-hero.png`
- `home-add-scan.svg`
- `home-add-manual.svg`
- `home-explore-teaser.svg`

### 필수 2차
- `saved-delete.svg`
- `saved-empty-bookmark.svg`
- `detail-edit.svg`
- `detail-delete.svg`
- `receipt-upload.svg`
- `receipt-gallery.svg`
- `receipt-camera-outline.svg`
- `receipt-camera-filled.svg`
- `explore-history.svg`
- `external-link.svg`

### 공통 재사용 후보
- `list-chevron-right.svg`
- `close-small.svg`
- `check-small.svg`
- `visibility-on.svg`
- `visibility-off.svg`
- `qty-minus.svg`
- `qty-plus.svg`
- `info-outline.svg`

## 8. 메모

- 지금 앱은 커스텀 아이콘 파일 시스템이 아니라 `Icons.*` 기반이라, 새 UI 아이콘을 넣으려면 다음 패스에서:
  1. asset 구조 추가
  2. 필요 시 `flutter_svg` 도입
  3. 각 `Icons.*` 자리를 새 asset widget으로 교체
  순서로 가면 된다.
- 반면 **런처 아이콘 / 로고 / splash / login hero**는 바로 교체 범위가 명확하다.
- 따라서 실제 체감 변화는 보통
  1. 런처 + 하단 네비 + 홈 대표 아이콘
  2. 마이/지난 카트/영수증 비교
  순으로 진행하는 게 좋다.
