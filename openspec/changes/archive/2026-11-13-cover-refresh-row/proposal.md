# Proposal

## Why

Row 20 is the last red fixture row that can be made honest. `RefreshIndicator` fires
a callback that produces no observable state, so even with `swipe` available there is
nothing to prove the refresh happened - and asserting "the gesture did not throw"
would be the exact success criterion this project rejects.

## What Changes

- Give the fixture's refresh an observable effect: a `RefreshController` that counts
  refreshes, registered with `Jig.state('refresh.count', ...)` the same way the other
  seven readers are.
- Add a test for row 20: the counter is zero, a downward swipe at the top of the list
  increments it, and the gesture is the only thing that could have.
- Mark row 20 automated in the matrix and take it off the queue.

Out of scope: any production change. `swipe` already emits the path; the missing half
is the fixture's, and this is the documented way to fix it.

## Capabilities

None. `skip_specs: true`.

## Impact

- `apps/fixture/lib/controllers.dart`, `pages/refresh_page.dart`, `main.dart`.
- New `apps/fixture/test/refresh_contract_test.dart`.
- `docs/fixture-matrix.md`, `docs/HANDOFF.md`.
