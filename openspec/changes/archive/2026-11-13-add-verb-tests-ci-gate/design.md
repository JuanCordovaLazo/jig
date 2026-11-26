# Design

## Context

See proposal.md for motivation. Current state: CI runs analysis only; `jig_protocol` is the sole package with tests. The verb logic lives in `JigActions` static methods (return `Map<String, Object?>` or throw `JigActionFailure`) and `ElementIndex`; only `extensions.dart` wraps results into `ServiceExtensionResponse`. This means verbs are callable in-process without the VM service. The Flutter/Dart toolchain is pinned in CI on purpose and must stay pinned.

## Goals / Non-Goals

**Goals:**
- A deterministic, device-free test gate where red means a real regression.
- Coverage focused on honest failure reporting, the defect class found on device.

**Non-Goals:**
- Testing the VM service transport or any real device/emulator behaviour.
- Fixing rows 20 and 21, or changing verb behaviour.

## Decisions

1. **Three layers.**
   - Pure-Dart unit tests (`bus`, `nav_history`, `state_registry`, `session_store`, CLI parsing, `jig_protocol`) with the `test` package.
   - `testWidgets` that pump fixture pages and call `JigActions.*` / `ElementIndex` directly under `tester.ensureSemantics()`.
   - Static analysis stays as is.
   Alternative: drive everything through the VM service on an emulator. Rejected: slow and flaky, which would erode the "red means something" rule.

2. **No device job in CI.** Device-found behaviour remains verified manually via the fixture matrix.

3. **No production seam by default.** Verbs are already static and return plain maps. A seam is a fallback only if a test cannot reach a behaviour, and it must not change the public contract, the ten-extension budget, or add a state-management dependency to `jig_flutter`.

4. **Fake-clock handling.** `_settle` and `_waitUntil` use real timing; under `flutter_test` they may need `tester.pump` loops or `runAsync`. Treat this as a finding to resolve while writing the first widget test, not by adding fixed sleeps to production code.

5. **Red rows stay out.** Rows 20 and 21 are not in the suite (an expected-failure test would hide the gap); they are listed as manual in docs. Row 11 (`BuggyController.confirm()`) is intentionally wrong and is not touched.

6. **Priority cases (fixture rows 1, 3, 9, 12-16, 18, 19):** covered tap returns an error not `ok`; `ELEMENT_NOT_VISIBLE`; `SCROLL_EXHAUSTED`; `ELEMENT_AMBIGUOUS`; `BACK_REFUSED`; zero-result `elements` includes `diag`.

7. **CI job.** A separate `test` job on the same pinned Flutter 3.47.7 / Dart 3.13.5, running each package's tests; `analyze` remains its own job.

## Risks / Trade-offs

- `JigActions`/`ElementIndex` may depend on `Jig.init` rather than only `WidgetsBinding` semantics → initialise `Jig` in test setup; if impossible, minimal seam per decision 3.
- Widget tests may differ from device timing/semantics → keep device-verified rows documented as manual; tests assert contract, not timing.
- Fixture apps may need a test-friendly entry point → import pages directly, not `main()`.
