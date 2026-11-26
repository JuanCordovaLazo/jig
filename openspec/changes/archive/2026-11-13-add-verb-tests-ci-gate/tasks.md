# Tasks

## 1. Pure-Dart unit tests

- [x] 1.1 Add the `test` dev-dependency to `jig_driver` and `jig_cli`, then verify `dart pub get` succeeds in the workspace
- [x] 1.2 Add unit tests for `session_store` and CLI argument parsing in `jig_cli`, and verify `dart test` passes there
- [x] 1.3 Add unit tests for the connection layer pure logic in `jig_driver` that needs no VM service, and verify `dart test` passes there
- [x] 1.4 Add unit tests for `bus`, `nav_history`, and `state_registry` in `jig_flutter`, and verify they pass with `flutter test`

## 2. Widget tests for verb honesty

- [x] 2.1 Add `flutter_test` to `jig_flutter`, build a shared test harness (`Jig` init, `ensureSemantics`, pump helpers), resolve `_settle`/`_waitUntil` fake-clock behaviour, and verify one smoke tap test passes
- [x] 2.2 Test that a tap on a covered target returns an error rather than `ok`, and verify it fails if the occlusion check is removed
- [x] 2.3 Test `ELEMENT_NOT_VISIBLE`, `SCROLL_EXHAUSTED`, and `ELEMENT_AMBIGUOUS` against fixture pages, and verify each asserts the error code
- [x] 2.4 Test `BACK_REFUSED` and that a zero-result `elements` call returns a `diag` block, and verify both pass
- [x] 2.5 Cover the remaining claim rows of `docs/fixture-matrix.md` (1, 3, 9, 12-16, 18, 19) not already covered, leaving rows 11, 20, and 21 out, and verify with `flutter test`
- [x] 2.6 If any test cannot reach its behaviour, add only a minimal seam that keeps the public contract and ten-extension budget, and verify `dart analyze .` and the extension count are unchanged

## 3. CI gate and docs

- [x] 3.1 Add a `test` job to `.github/workflows/ci.yml` on the pinned Flutter 3.47.7 toolchain running all package tests, and verify the workflow YAML parses and the job passes on a pushed branch
- [x] 3.2 Update `docs/fixture-matrix.md` and `docs/HANDOFF.md` to mark which rows are automated and that rows 20 and 21 remain manual and red, and verify the docs match the test files

## 4. Integration check

- [x] 4.1 Run `dart analyze .`, `flutter analyze` in `apps/fixture`, and every package test suite locally from a clean checkout, and verify all are green
