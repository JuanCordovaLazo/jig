# Proposal

## Why

CI only runs `dart analyze` and `flutter analyze`; nothing executes. Every defect found on device so far was behavioural: a verb reported something other than what happened (for example, a tap on a covered button returned `ok`). Static analysis cannot catch that class of bug, and only `jig_protocol` has any tests today. Before widening the surface (`audit`, `run`, gestures), the existing verbs need a regression net that makes a red CI mean something.

## What Changes

- Add in-process widget tests that pump fixture pages and call the existing verb entry points directly, prioritising honest-failure cases: covered target, `ELEMENT_NOT_VISIBLE`, `SCROLL_EXHAUSTED`, `ELEMENT_AMBIGUOUS`, `BACK_REFUSED`, and "zero results must say why" (`diag`).
- Add pure-Dart unit tests for the event bus, navigation history, state registry, session store, and CLI argument parsing.
- Add a `test` job to CI on the pinned toolchain (Flutter 3.47.7 / Dart 3.13.5) that runs the suites for every package that has tests.
- Fixture matrix rows 20 and 21 (refresh, slidable) stay intentionally red and are excluded from the suite so the gap is not hidden. Row 11 (`BuggyController.confirm()`) is left untouched.
- No production behaviour change is planned. A minimal seam in verb code is allowed only if a test cannot reach the behaviour otherwise, and must keep the public contract, the ten-extension budget, and the no-state-library rule intact.
- Out of scope: device or emulator CI jobs, VM service transport tests, new verbs, gestures, and an `integration_test` export.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This is tooling and verification only; no requirement in `agent-harness` changes, so the change sets `skip_specs: true`.

## Impact

- New `test/` directories and `dev_dependencies` (`test`, `flutter_test`) in `packages/jig_flutter`, `packages/jig_driver`, `packages/jig_cli`, and possibly `packages/jig_getx` and `apps/fixture`.
- `.github/workflows/ci.yml`: new `test` job alongside `analyze`.
- `docs/fixture-matrix.md` and `docs/HANDOFF.md`: note which rows are covered by automated tests and that rows 20 and 21 remain manual and red.
- Production code in `packages/jig_flutter` is untouched unless a minimal test seam proves necessary.
