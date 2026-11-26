# Proposal

## Why

Every check today is one command typed by an agent that reads the JSON and decides
what to do next. That loop is where sessions get long and where a step gets skipped:
the harness cannot tell a healthy flow from one whose last three steps were never
run. A scenario is the same sequence, written once, executable in one command, with a
report that says which step failed.

## What Changes

- Add `jig run <file>`: executes a JSON scenario of verb steps against the app and
  prints one report.
- Stop at the first failing step, mark the rest as skipped, and exit `1`. A run that
  hid a failure behind later ones would be the same lie as a tap that reports `ok`.
- Add `expect` to the `state` step so a scenario asserts values, with a distinct
  `EXPECTATION_FAILED` code for a mismatch.
- Add `JigVerbs` to `jig_driver`: the verb set as an interface `JigConnection`
  implements, so the runner is unit-testable against a fake without a device.

Out of scope, and each is its own change: `record` (deriving a scenario from a live
session), `eval` as a step (it needs argument plumbing the other verbs do not), and
any conditional or looping control flow.

## Capabilities

None. `skip_specs: true`.

## Impact

- New `packages/jig_cli/lib/src/scenario.dart` (parse and validate) and
  `runner.dart` (execute), plus one dispatch case and usage text.
- `packages/jig_driver`: a `JigVerbs` interface, four lines on `JigConnection`.
- `packages/jig_protocol`: one error code.
- Unit tests in `jig_cli` against a fake driver; one scenario committed as an example.
