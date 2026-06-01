# Material → SF Symbols 매핑

생성일: 2026-05-08

## 1. 하단 네비게이션

파일: `lib/pages/home_page.dart`

| 위치 | Flutter Icon | SF Symbol |
|---|---|---|
| 홈 탭 (기본) | `Icons.home_outlined` | `cart` |
| 홈 탭 (선택) | `Icons.home` | `cart.fill` |
| 탐색 탭 (기본) | `Icons.explore_outlined` | `magnifyingglass` |
| 탐색 탭 (선택) | `Icons.explore` | `sparkle.magnifyingglass` |
| 마이 탭 (기본) | `Icons.person_outline` | `person.crop.circle` |
| 마이 탭 (선택) | `Icons.person` | `person.crop.circle.fill` |

## 2. 홈 — 현재 카트

파일: `lib/widgets/current_cart_section.dart`

| 위치 | Flutter Icon | SF Symbol |
|---|---|---|
| empty state | `Icons.shopping_cart_outlined` | `basket` |
| swipe delete | `Icons.delete_outline_rounded` | `trash.fill` |
| 펼침 상태 | `Icons.keyboard_arrow_up_rounded` | `chevron.up` |
| 접힘 상태 | `Icons.keyboard_arrow_down_rounded` | `chevron.down` |
| 수량 감소 | `Icons.remove_rounded` | `minus` |
| 수량 증가 | `Icons.add_rounded` | `plus` |

## 3. 홈 — 새 상품 추가 / 최근 스캔

파일: `lib/widgets/item_add_section.dart`

| 위치 | Flutter Icon | SF Symbol |
|---|---|---|
| 가격표 인식하기 | `Icons.camera_alt` | `camera` |
| 직접 추가하기 | `Icons.edit` | `long.text.page.and.pencil` |
| 최근 스캔 row 이동 | `Icons.chevron_right` | `chevron.right` |
| 최근 스캔 지우기 | `Icons.close` | `eraser.fill` |

## 4. 홈 하단 Explore 유도

파일: `lib/pages/home_tab_view.dart`

| 위치 | Flutter Icon | SF Symbol |
|---|---|---|
| Explore teaser | `Icons.explore_outlined` | `sparkle.magnifyingglass` |

## 5. 마이 페이지

파일: `lib/pages/my_page.dart`

| 위치 | Flutter Icon | SF Symbol |
|---|---|---|
| 회원 상태 | `Icons.history_toggle_off_rounded` | `person.circle` |
| 게스트 상태 | `Icons.shopping_bag_outlined` | `person` |
| 혜택/체크 칩 | `Icons.check_rounded` | `checkmark` |

## 6. 지난 카트 목록

파일: `lib/widgets/saved_tab_*.dart`

| 위치 | Flutter Icon | SF Symbol |
|---|---|---|
| empty state | `Icons.bookmark_border` | `bookmark` |
| 카드 진입 | `Icons.chevron_right` | `chevron.right` |
| swipe 삭제 | `Icons.delete_outline_rounded` | `trash.fill` |

## 7. 저장 카트 다시 담기

파일: `lib/widgets/saved_cart_item_add_section.dart`

| 위치 | Flutter Icon | SF Symbol |
|---|---|---|
| 열기 | `Icons.add` | `plus` |
| 닫기 | `Icons.close` | `xmark` |

## 8. 카트 상세

파일: `lib/widgets/cart_detail_*.dart`

| 위치 | Flutter Icon | SF Symbol |
|---|---|---|
| item 수정 | `Icons.edit_outlined` | `pencil.tip` |
| item 삭제 | `Icons.close` | `xmark` |
| 수량 감소 | `Icons.remove_circle_outline` | `minus.circle` |
| 수량 증가 | `Icons.add_circle_outline` | `plus.circle` |
| 영수증 비교 없음 | `Icons.receipt_long_outlined` | `checklist.unchecked` |
| 영수증 비교 있음 | `Icons.receipt_long` | `checklist.checked` |
| 상단 삭제 | `Icons.delete_outline` | `trash` |
| 게스트 리텐션 | `Icons.lock_outline_rounded` | `lock` |
| 추가 row | `Icons.chevron_right` | `chevron.right` |

## 9. 탐색 (Explore)

파일: `lib/pages/shopping_help_page.dart, lib/widgets/inline_promo_slot.dart`

| 위치 | Flutter Icon | SF Symbol |
|---|---|---|
| 장보기 시작 CTA | `Icons.shopping_cart_checkout_rounded` | `cart.badge.plus` |
| 가린 대안 다시 보기 | `Icons.visibility_rounded` | `eyeglasses` |
| 추천/채택 표시 | `Icons.check_circle_outline_rounded` | `checkmark.circle` |
| 지난 장보기 문맥 | `Icons.history_rounded` | `arrow.uturn.backward.circle` |
| 숨김 처리 | `Icons.visibility_off_rounded` | `eyeglasses.slash` |
| 홈 시작 fallback | `Icons.home_rounded` | `cart` |
| 최근 장보기 이어보기 | `Icons.shopping_bag_rounded` | `cart.circle.fill` |
| 지난 카트 전체 보기 | `Icons.history_rounded` | `clock.arrow.circlepath` |
| 외부 제휴 링크 | `Icons.open_in_new_rounded` | `square.and.arrow.up` |
| 인라인 프로모 (클릭) | `Icons.open_in_new` | `square.and.arrow.up` |
| 인라인 프로모 (혜택) | `Icons.local_offer_outlined` | `tag` |

## 10. 영수증 비교

파일: `lib/pages/receipt_comparison_page.dart`

| 위치 | Flutter Icon | SF Symbol |
|---|---|---|
| 영수증 올리기 | `Icons.receipt_long_outlined` | `receipt` |
| 원문 보기 | `Icons.visibility_outlined` | `eyeglasses` |
| 원문 숨기기 | `Icons.visibility_off_outlined` | `eyeglasses.slash` |
| 카메라 placeholder | `Icons.camera_alt_outlined` | `camera` |
| 갤러리 선택 | `Icons.photo_library_outlined` | `photo.on.rectangle.angled` |
| 카메라 촬영 | `Icons.camera_alt` | `camera.fill` |

## 11. 완료 / 드로어 / 공통

파일: `lib/widgets/save_complete_bottom_sheet.dart, lib/widgets/cartly_end_drawer.dart`

| 위치 | Flutter Icon | SF Symbol |
|---|---|---|
| 저장 완료 | `Icons.check_circle` | `checkmark.circle.fill` |
| drawer row 진입 | `Icons.chevron_right` | `chevron.right` |
| drawer 안내 | `Icons.info_outline` | `info.circle` |

## 유니크 매핑 요약

| Flutter Icon | SF Symbol(s) |
|---|---|
| `Icons.add` | `plus` |
| `Icons.add_circle_outline` | `plus.circle` |
| `Icons.add_rounded` | `plus` |
| `Icons.bookmark_border` | `bookmark` |
| `Icons.camera_alt` | `camera`, `camera.fill` |
| `Icons.camera_alt_outlined` | `camera` |
| `Icons.check_circle` | `checkmark.circle.fill` |
| `Icons.check_circle_outline_rounded` | `checkmark.circle` |
| `Icons.check_rounded` | `checkmark` |
| `Icons.chevron_right` | `chevron.right` |
| `Icons.close` | `eraser.fill`, `xmark` |
| `Icons.delete_outline` | `trash` |
| `Icons.delete_outline_rounded` | `trash.fill` |
| `Icons.edit` | `long.text.page.and.pencil` |
| `Icons.edit_outlined` | `pencil.tip` |
| `Icons.explore` | `sparkle.magnifyingglass` |
| `Icons.explore_outlined` | `magnifyingglass`, `sparkle.magnifyingglass` |
| `Icons.history_rounded` | `arrow.uturn.backward.circle`, `clock.arrow.circlepath` |
| `Icons.history_toggle_off_rounded` | `person.circle` |
| `Icons.home` | `cart.fill` |
| `Icons.home_outlined` | `cart` |
| `Icons.home_rounded` | `cart` |
| `Icons.info_outline` | `info.circle` |
| `Icons.keyboard_arrow_down_rounded` | `chevron.down` |
| `Icons.keyboard_arrow_up_rounded` | `chevron.up` |
| `Icons.local_offer_outlined` | `tag` |
| `Icons.lock_outline_rounded` | `lock` |
| `Icons.open_in_new` | `square.and.arrow.up` |
| `Icons.open_in_new_rounded` | `square.and.arrow.up` |
| `Icons.person` | `person.crop.circle.fill` |
| `Icons.person_outline` | `person.crop.circle` |
| `Icons.photo_library_outlined` | `photo.on.rectangle.angled` |
| `Icons.receipt_long` | `checklist.checked` |
| `Icons.receipt_long_outlined` | `checklist.unchecked`, `receipt` |
| `Icons.remove_circle_outline` | `minus.circle` |
| `Icons.remove_rounded` | `minus` |
| `Icons.shopping_bag_outlined` | `person` |
| `Icons.shopping_bag_rounded` | `cart.circle.fill` |
| `Icons.shopping_cart_checkout_rounded` | `cart.badge.plus` |
| `Icons.shopping_cart_outlined` | `basket` |
| `Icons.visibility_off_outlined` | `eyeglasses.slash` |
| `Icons.visibility_off_rounded` | `eyeglasses.slash` |
| `Icons.visibility_outlined` | `eyeglasses` |
| `Icons.visibility_rounded` | `eyeglasses` |
