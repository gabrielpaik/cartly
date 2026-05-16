# 2026-05-16 Cartly checkpoint handoff

## Current checkpoint

This checkpoint includes the recent customer-app passes around receipt-applied cart quality and My page categorization.

### Included
- receipt-applied cart title normalization and unified title formatting
- discount-purchase metadata/display in saved cart detail
- customer-facing timeline/title cleanup across saved-cart surfaces
- stronger category inference for food/fresh groceries/snacks/brand cues
- customer-editable category override flow in My monthly category sheet
- persisted cart item category label/source support for manual overrides
- shipped TestFlight builds through `1.0.4 (16)` during this pass

## Current product direction
- Keep customer price input simple: one price only.
- Enrich discount metadata only when trusted sources like receipt OCR or scan output can provide it.
- Category quality should improve from both sides:
  - stronger default inference
  - customer manual correction when inference is wrong

## Next work

**Primary next task: design detail polish.**

Focus the next pass on UI/interaction detail refinement rather than larger product-model changes.

### Recommended focus areas
- My monthly category bottom sheet spacing, hierarchy, and tap affordance polish
- category chip/button visual clarity
- saved-cart detail discount badge/layout polish
- title/date/subcopy balance across saved-cart surfaces
- consistency of iconography for newly expanded category families
- reduce any awkward density or visual noise introduced by the new controls

## Notes
- There are untracked temp preview PNGs under `admin-web/.tmp-*`; they are not part of this checkpoint.
- If category misses remain, collect real product-name examples first and tune the dictionary from evidence, not guesswork.
