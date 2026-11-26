# Proposal

## Why

Ten of the twenty-one fixture rows are now proven by `flutter test`; the other
eleven are checked by hand on a device or not at all. Rows 2, 5, 6, 7, 8, 10 and 17
are all reachable in-process, so leaving them manual means seven documented defect
classes can regress without anything going red.

## What Changes

- Add tests for rows 2, 5, 6, 7, 8, 10 and 17 in `apps/fixture/test`, using the
  existing harness.
- Cover the two rows whose claim lives in transport (6 and 7) by running the real
  loopback `FakeBackend` inside `tester.runAsync`, so a socket can complete while
  the widget clock stays fake.
- Move those rows from manual to automated in `docs/fixture-matrix.md`, and update
  the test count in `docs/HANDOFF.md`.

Out of scope: rows 20 and 21 (they need a pointer path), row 11 (red on purpose),
and any change to verb behaviour.

## Capabilities

None. The requirements these rows evidence are already in
`openspec/specs/agent-harness/spec.md`; this change adds proof, not claims, so it
sets `skip_specs: true`.

## Impact

- New test files under `apps/fixture/test`; possibly one harness helper for
  socket-backed cases.
- `docs/fixture-matrix.md`, `docs/HANDOFF.md`.
- No production code change is planned.
