# Proposal

## Why

The fixture targets SDK 36 and runs on API 37, where Android draws the app behind the
status and navigation bars and does not let it opt out. Vitrine-reviewing the app with
`jig screenshot` and `jig tree` shows the top inset is right everywhere and the bottom
inset is wrong wherever a constant was written.

Measured on 1080x2400 at 420dpi: status bar `0..63`, navigation bar `2274..2400`.

- The home list's last row ended at `2358`, i.e. 84px inside the bar, because
  `padding: const EdgeInsets.all(16)` replaces the inset a scroll view derives from
  `MediaQuery`.
- The overlays page's bottom-anchored button ended at `2358` for the same reason.
- The bottom sheet's button ended at `2337`, 63px into the bar.

Pages that never wrote a padding were already correct: the long list's last row lands at
exactly `2274`, and the FAB, the keyboard case and the GetX snackbar were right on their
own. That contrast is the whole finding: one constant loses the inset, no constant keeps
it.

## What Changes

- `apps/fixture/lib/insets.dart`: `pagePadding(context, {all})`, the page padding with
  `MediaQuery.viewPadding.bottom` added.
- Home and form lists, the overlays page body and the bottom sheet use it.
- `apps/fixture/test/edge_to_edge_test.dart` asserts, on a simulated 1080x2400 screen with
  a 63px top and 126px bottom inset, that the first row clears the status bar and that the
  last row clears the navigation bar at full scroll.
- `docs/fixture-matrix.md` records the geometry, the three defects and what was already
  correct.

Out of scope: the library packages, and the snackbar's ~18px background overlap, which is
GetX's own SafeArea and not the app's to override.

## Capabilities

No spec-level change; jig's behaviour is untouched. `skip_specs: true`.

## Impact

`apps/fixture` (one new file, four call sites, one test), docs.
