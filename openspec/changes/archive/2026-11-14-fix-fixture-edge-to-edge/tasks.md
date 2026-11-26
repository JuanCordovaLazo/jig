# Tasks

## 1. Measure the geometry

- [x] 1.1 Read the insets from the device (`dumpsys window` `InsetsSource` frames: status
      `0..63`, navigation `2274..2400` on 1080x2400 at 420dpi) and confirm the Flutter
      frame covers the whole screen, which is what makes edge-to-edge real here.
- [x] 1.2 Measure every surface that reaches an edge with `jig tree` rects, and classify:
      home list, overlays page, bottom sheet, long list, FAB, keyboard case, snackbar.

## 2. Fix what is wrong

- [x] 2.1 Add `pagePadding` in `apps/fixture/lib/insets.dart` and use it in the home and
      form lists, the overlays page body and the bottom sheet; verify with
      `flutter analyze` in `apps/fixture`.
- [x] 2.2 Re-measure on the emulator: home last row, overlays button and sheet button must
      all end above 2274; verify with `jig tree` and a capture of each.

## 3. Guard it

- [x] 3.1 `apps/fixture/test/edge_to_edge_test.dart` asserts the top and bottom insets on
      a simulated 1080x2400 view; verify it fails with the old constant and passes with the
      helper (`flutter test test/edge_to_edge_test.dart`).
- [x] 3.2 Record the geometry and the three defects in `docs/fixture-matrix.md` and update
      the counts in `docs/HANDOFF.md`; verify `./tool/verify.sh` passes.

## Workflow follow-up

- Archive the change once the device re-measurement is recorded.
