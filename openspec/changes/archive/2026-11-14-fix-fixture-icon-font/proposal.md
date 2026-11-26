# Proposal

## Why

The fixture renders tofu boxes wherever it draws an icon. `apps/fixture/pubspec.yaml` has
no `flutter:` section, so `uses-material-design` defaults to false and
`MaterialIcons-Regular.otf` is never bundled: all eleven `Icons.*` in the app compile,
pass every test, produce nothing in the semantics tree, and render as a rectangle.

It was found by a human looking at a `jig screenshot`, which is the only check that sees
pixels. `dart analyze` is clean, `flutter test` is green, and the accessibility tree reads
the same either way - an `IconButton` with an icon font or without one has an empty label.

## What Changes

- `apps/fixture/pubspec.yaml` gains `flutter: uses-material-design: true`, which bundles
  the Material icon font.
- `apps/fixture/test/icons_test.dart` loads `fonts/MaterialIcons-Regular.otf` from the
  asset bundle and fails when it is absent. Widget tests read the same bundle the app is
  built with, so the guard runs in the gate with no device.
- `docs/fixture-matrix.md` and `docs/HANDOFF.md` record that a capture found this, and
  what the guard covers.

Out of scope: any other app's assets. Library packages do not bundle fonts, so
`jig_flutter` is unaffected.

## Capabilities

No spec-level change; behaviour of jig is untouched. `skip_specs: true`.

## Impact

`apps/fixture` (pubspec, one new test), docs. No change to any package under
`packages/`.
