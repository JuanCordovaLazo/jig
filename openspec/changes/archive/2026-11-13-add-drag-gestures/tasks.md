# Tasks

## 1. The gesture

- [x] 1.1 Add `GESTURE_NO_EFFECT` to the protocol error enum and document it in `docs/CONTRACT.md`, then verify `dart analyze .`
- [x] 1.2 Add `JigActions.swipe` in `jig_flutter` with the two proofs of design.md decision 3 (hit-test at the origin, observable effect after), and unit-test the no-effect path

## 2. The surface

- [x] 2.1 Route `gesture=swipe` through the existing `ext.jig.tap` handler, add `JigConnection.swipe`, and add the `swipe --direction` CLI command, then verify the extension count is still 10
- [x] 2.2 Test fixture row 21 end to end: `slidable_delete` is absent, a swipe reveals it, and a tap on it works

## 3. Prove the proof

- [x] 3.1 Verify a swipe on an element that cannot move fails with `GESTURE_NO_EFFECT` instead of reporting `ok`, and that a covered element fails `ELEMENT_NOT_VISIBLE` without emitting events

## 4. Keep the rules and docs true

- [x] 4.1 Amend the pointer-path rule in `docs/HANDOFF.md`, `CONTRIBUTING.md`, `README.md` and `docs/fixture-matrix.md` so it states the proof obligation instead of an absolute ban, and mark row 21 automated
- [x] 4.2 Run `./tool/verify.sh` and confirm it reports `All checks passed.`
