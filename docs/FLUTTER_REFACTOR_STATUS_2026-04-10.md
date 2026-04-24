# Flutter Refactor Status - 2026-04-10

## Summary

The Flutter app refactor reached a good stopping point on 2026-04-10.

This pass stayed disciplined:
- small extraction batches only
- no UX redesign
- no backend/admin/platform edits mixed into Flutter refactor commits
- `flutter analyze` re-run after each safe batch
- each safe batch checkpointed in git immediately

The result is a much flatter, more navigable Flutter app structure with the major oversized pages decomposed into clearer view, section, and helper files.

## What is now structurally improved

### 1. App entry and shell
- `lib/main.dart` is now a thin entrypoint.
- startup/bootstrap moved out
- app shell/lifecycle wiring moved out
- home page shell/orchestration moved out

Key files:
- `lib/main.dart`
- `lib/app/app_bootstrap.dart`
- `lib/app/cartly_app.dart`
- `lib/app_support.dart`

### 2. Home flow
Home flow is now meaningfully decomposed.

Key files:
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
- `lib/widgets/inline_promo_slot.dart`
- `lib/pages/my_page.dart`

### 3. Saved flow
Saved flow is now split into small, readable view and widget surfaces.

Key files:
- `lib/pages/saved_tab_view.dart`
- `lib/widgets/saved_cart_list_card.dart`
- `lib/widgets/saved_cart_list_card_content.dart`
- `lib/widgets/saved_cart_list_card_header.dart`
- `lib/widgets/saved_tab_empty_state.dart`
- `lib/widgets/saved_tab_header.dart`
- `lib/widgets/saved_tab_list_entry.dart`
- `lib/widgets/saved_tab_cart_list.dart`

### 4. Cart detail flow
`cart_detail_page.dart` was one of the highest-ROI targets and is now in a much healthier state.

Key files:
- `lib/pages/cart_detail_page.dart`
- `lib/pages/cart_detail_page_helpers.dart`
- `lib/widgets/cart_detail_guest_retention_section.dart`
- `lib/widgets/cart_detail_bottom_bar.dart`
- `lib/widgets/cart_detail_item_tile.dart`
- `lib/widgets/cart_detail_delete_confirmation_sheet.dart`
- `lib/widgets/cart_detail_app_bar_actions.dart`
- `lib/widgets/cart_detail_body.dart`
- `lib/widgets/cart_detail_edit_actions_section.dart`

### 5. Login flow
`login_page.dart` also reached a solid stopping point.

Key files:
- `lib/pages/login_page.dart`
- `lib/widgets/login_page_header_section.dart`
- `lib/widgets/login_page_guest_cta_section.dart`
- `lib/widgets/login_page_auth_form_section.dart`
- `lib/widgets/login_page_auth_dialogs.dart`

## Current key file sizes

These are the main “before-vs-now” indicators of the refactor result.

- `lib/main.dart`: 9 lines
- `lib/pages/home_page.dart`: 133 lines
- `lib/pages/home_tab_view.dart`: 129 lines
- `lib/pages/saved_tab_view.dart`: 41 lines
- `lib/pages/cart_detail_page.dart`: 282 lines
- `lib/pages/login_page.dart`: 413 lines

Interpretation:
- `main.dart`, `home`, and `saved` are now in good structural shape.
- `cart_detail_page.dart` is no longer a major structural risk.
- `login_page.dart` is still moderately large, but the remaining logic is mostly page-owned auth flow/state, so further splitting should be more selective.

## Commit trail for this refactor run

### Baseline and rename checkpoints
- `5c127b7` Checkpoint Cartly product baseline before rename pass
- `dacde4b` Finish low-risk Cartly rename in active runtime surfaces

### Flutter refactor checkpoints
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
- `f839b7e` Document Flutter refactor status and next target
- `90ebe7b` Extract cart detail guest retention section
- `35038ed` Extract cart detail bottom bar
- `b4beeeb` Extract cart detail item tile
- `f4e6d4d` Extract cart detail delete confirmation sheet
- `eebd987` Extract cart detail app bar actions
- `72c37db` Extract cart detail body switch
- `b1fba4c` Extract cart detail edit actions section
- `73a74f8` Extract cart detail helper logic
- `6b6243d` Extract login page header section
- `50e8e0f` Extract login page guest CTA section
- `ffaf360` Extract login page auth form section
- `689b2f3` Extract login page auth dialogs

## Current repo state after Flutter cleanup

The Flutter refactor work itself is checkpointed.

Current dirty tree is mostly outside the refactor scope:
- iOS app icon changes
- untracked platform scaffolding (`android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/`)
- local/tooling paths such as `.claude/` and `tmp/`

This means the Flutter lib-level cleanup is in a good stopping state and should not be conflated with platform repository decisions.

## Review judgment

### What succeeded
- The large pages were reduced without drifting into redesign.
- Refactor work stayed evidence-based and reversible because every batch was analyzed and committed.
- The riskiest oversized files were handled first.
- Page responsibilities are now clearer:
  - shell/bootstrap
  - view sections
  - dialog/sheet helpers
  - page-owned flow logic

### What should not be overdone now
- `home` and `saved` should not be micro-split further.
- `cart_detail_page.dart` is at a good stopping point.
- `login_page.dart` should stop here unless there is a concrete bug or feature need, because the remaining complexity is mostly authentic page-owned auth state/flow.

## Recommended next move

Do not continue Flutter micro-refactoring right now.

Next highest-value work should be one of these:
1. review and classify platform/untracked files
2. decide which platform scaffolding belongs in source control
3. move back to product work on a now-cleaner Flutter structure

If Flutter refactoring resumes later, it should be because of a concrete new need, not because the current pages still have any remaining extractable code.
