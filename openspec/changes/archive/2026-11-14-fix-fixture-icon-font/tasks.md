# Tasks

## 1. The defect and its guard

- [x] 1.1 Add a failing test that loads `fonts/MaterialIcons-Regular.otf` from the
      bundle, confirm it fails with "Unable to load asset", then add
      `uses-material-design: true` and confirm `flutter test` in `apps/fixture` passes.
- [x] 1.2 Verify on the emulator that icons render: `jig screenshot` of the home screen
      shows the menu, star and chevron glyphs, and of a pushed route shows the back
      arrow.
- [x] 1.3 Record in `docs/fixture-matrix.md` and `docs/HANDOFF.md` that a capture found
      this and what the new test covers; verify `./tool/verify.sh` reports 128 tests.

## Workflow follow-up

- Archive the change once the device capture is confirmed.
