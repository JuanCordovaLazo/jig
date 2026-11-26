# Tasks

## 1. Make the refresh observable

- [x] 1.1 Add `RefreshController` to `apps/fixture/lib/controllers.dart` and have `RefreshPage` count through it, then register `Jig.state('refresh.count', ...)` in `main.dart`

## 2. Prove the row

- [x] 2.1 Add `apps/fixture/test/refresh_contract_test.dart`: the counter is `0`, a `--direction down` swipe at the top of the list makes it `1`, and the swipe reports success only because that number moved
- [x] 2.2 Verify a downward swipe on a list that cannot refresh fails with `GESTURE_NO_EFFECT`, so the counter is what the assertion rests on

## 3. Close it

- [x] 3.1 Mark row 20 automated in `docs/fixture-matrix.md`, update the counts in `docs/HANDOFF.md`, and remove the row from the queue
- [x] 3.2 Run `./tool/verify.sh` and confirm it reports `All checks passed.`
