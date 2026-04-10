# Flutter Refactor Status - 2026-04-10

## Summary

The Flutter app refactor completed a long safe-split sequence focused on reducing file density without changing runtime behavior.

Principles used throughout:
- small extraction batches only
- no UX redesign
- no backend/admin/platform edits mixed into Flutter refactor commits
- `flutter analyze` re-run after every batch
- each safe batch checkpointed in git immediately

## What is now structurally improved

### App entry and shell
- `lib/main.dart` is now a thin entrypoint, down to 9 lines.
- startup/bootstrap moved out
- app shell/lifecycle wiring moved out
- home page shell/orchestration moved out

### Home flow
Refactor work completed across home-related surfaces:
- `lib/app/app_bootstrap.dart`
- `lib/app/wimc_app.dart`
- `lib/pages/home_page.dart`
- `lib/pages/home_page_cart_save_controller.dart`
- `lib/pages/home_page_cart_controller.dart`
- `lib/pages/home_tab_view.dart`
- `lib/widgets/save_complete_bottom_sheet.dart`
- `lib/widgets/current_cart_section.dart`
- `lib/widgets/recent_saved_preview_card.dart`
- `lib/widgets/recent_scan_card.dart`
- `lib/widgets/section_header.dart`
- `lib/widgets/total_bar.dart`
- `lib/widgets/context_pill.dart`

### Saved flow
Refactor work completed across saved-related surfaces:
- `lib/pages/saved_tab_view.dart`
- `lib/widgets/saved_cart_list_card.dart`
- `lib/widgets/saved_cart_list_card_content.dart`
- `lib/widgets/saved_cart_list_card_header.dart`
- `lib/widgets/saved_tab_empty_state.dart`
- `lib/widgets/saved_tab_header.dart`
- `lib/widgets/saved_tab_list_entry.dart`
- `lib/widgets/saved_tab_cart_list.dart`

### Shared support extracted earlier
- `lib/app_support.dart`
- `lib/pages/my_page.dart`
- `lib/widgets/inline_promo_slot.dart`

## Current key file sizes

- `lib/main.dart`: 9 lines
- `lib/pages/home_page.dart`: 133 lines
- `lib/pages/home_tab_view.dart`: 129 lines
- `lib/pages/saved_tab_view.dart`: 41 lines
- `lib/widgets/saved_cart_list_card.dart`: 56 lines
- `lib/pages/cart_detail_page.dart`: 786 lines
- `lib/pages/login_page.dart`: 773 lines

## Commit trail for this refactor run

- `ab351a8` Refactor Flutter app shell by extracting main tab views
- `9b581fd` Refactor Flutter app bootstrap and home shell
- `e04cd76` Extract save complete bottom sheet from home page
- `befdd83` Extract home page cart save orchestration
- `0f14004` Extract home page cart state helpers
- `3e62f03` Extract current cart section from home tab
- `0a797d3` Extract recent saved preview card from home tab
- `777a8ec` Extract recent scan card from home tab
- `d1710dd` Extract section header from home tab
- `e9ccd50` Extract total bar from home tab
- `d1c354a` Extract shared context pill widget
- `26db0f9` Extract saved cart list card from saved tab
- `60bb001` Extract saved tab empty state
- `78c4e26` Extract saved tab list entry composition
- `b07c267` Extract saved tab header
- `a65b879` Extract saved tab cart list body
- `65e4206` Extract saved cart list card content
- `ba01246` Extract saved cart list card header

## Current repo state after Flutter cleanup

Flutter product code from this refactor run is checkpointed.

Remaining dirty tree is mostly outside this refactor scope:
- iOS platform/app icon changes
- untracked Flutter platform scaffolding (`android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/`)
- local/tooling paths like `.claude/` and `tmp/`

That means the Flutter app refactor itself is in a good stopping state.

## Recommended next target

Do not keep micro-splitting the already-small home/saved files.

Highest ROI next target:
1. `lib/pages/cart_detail_page.dart`
2. `lib/pages/login_page.dart`

Reason:
- both are still very large
- both still mix UI, state, and action/orchestration logic
- further cleanup there will produce much bigger maintainability wins than continuing tiny widget splits elsewhere

## Recommended next move

Start with `lib/pages/cart_detail_page.dart` and use the same pattern:
- conservative extraction only
- one responsibility per batch
- analyze after each batch
- commit every safe checkpoint
