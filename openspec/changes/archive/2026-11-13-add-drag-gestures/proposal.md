# Proposal

## Why

Rows 20 and 21 of the fixture need a pointer path, and both are documented as
permanently red: `slidable_delete` does not exist in the tree until a drag happens,
and `RefreshIndicator` publishes no action at all. Two of the twenty-one documented
failure modes therefore cannot be covered, and the harness cannot reach a class of
control that every real app has.

## What Changes

- Add a `swipe` verb that emits a real pointer path at an element, in a named
  direction, with the distance derived from that element's own size.
- Prove the gesture twice before calling it a success: the origin must hit-test to
  the target, and the app must visibly change afterwards. A swipe that changes
  nothing is an error, never `ok`.
- Add a `GESTURE_NO_EFFECT` wire code for that second failure, because "the gesture
  did nothing" is exactly the class of lie this project exists to remove.
- Reuse the existing `ext.jig.tap` extension with a `gesture` parameter, so the
  ten-extension budget is untouched.
- Automate fixture row 21; amend the "pointer paths are out of scope" rule in
  HANDOFF, CONTRIBUTING and the matrix so it states the proof obligation instead.

Out of scope: row 20 (needs the fixture to expose the refresh as observable state),
multi-touch, and any caller-supplied coordinate.

## Capabilities

None. The requirement "a gesture that cannot be proven to have reached its target is
not a success" already exists and is unchanged; this change adds evidence for it and
a new verb. `skip_specs: true`.

## Impact

- `jig_flutter`: `JigActions.swipe`, `jig_protocol`: one error code.
- `jig_driver`: one verb; `jig_cli`: one command.
- `apps/fixture/test`: row 21; docs: rule wording, matrix row, verb count.
