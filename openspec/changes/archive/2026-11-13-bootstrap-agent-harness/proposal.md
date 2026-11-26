## Why

Flutter end-to-end work is rebuilt from scratch every time. Each question about a
running app turns into a new throwaway driver script whose first 90% is
plumbing - discovering the VM service, walking the widget tree, guessing
positions, retrying - and whose last 10% is the actual check. The plumbing is
what breaks, and it breaks again next week.

Existing harnesses fail on the same two points:

- they act on coordinates, so a rebuild between "find" and "tap" makes the
  position wrong, and an overlay can absorb the tap without anyone noticing;
- they cannot see the state that matters, because GetX keeps it in a service
  locator rather than in the widget tree.

The result is a tool that is either expensive to maintain (`flutter_skill` is a
single ~3,800 line class with ~40 extensions) or too small to replace it
(`marionette_flutter` requires a custom binding and manual selector work for
custom design systems).

This change builds `jig`: a rig that holds the app and guides the agent. It acts
through the accessibility tree, derives positions only at the instant of the
action, reads state through named readers, and reports failures with a candidate
list and a next command instead of a stack trace.

## What Changes

- New public repository `jig` with five Dart packages under a pub workspace:
  `jig_protocol`, `jig_driver`, `jig_flutter`, `jig_getx`, `jig_cli`.
- `jig_protocol`: the wire contract - selectors, elements, events, responses,
  error codes - with an explicit stability policy.
- `jig_flutter`: app-side runtime behind `kDebugMode`. An event bus with a
  monotonic sequence, a semantics-driven element index, actions that go through
  `SemanticsOwner`, waits evaluated inside the UI isolate, a named state
  registry, and eight VM service extensions. No custom binding, no overlay.
- `jig_getx`: `JigConnect extends GetConnect`, which instruments every repository
  under a base class with one word changed. Also captures the app's log writer,
  whose signature is structurally identical to GetX's `LogWriterCallback`, so
  `jig_flutter` keeps no dependency on `get`.
- `jig_driver` / `jig_cli`: VM service transport, twelve verbs, one JSON envelope
  per command, `seq` in the envelope so a caller can chain an action into
  `events --since`.
- `apps/fixture`: a GetX conformance app that reproduces eleven named failure
  modes on purpose, including a flow that must fail. This is the asset that makes
  parity claims checkable.
- Out of scope for this change: the MCP frontend, scenario runner, recording,
  `audit`, iOS, gestures beyond tap and long press.

## Impact

- Affected specs: `agent-harness` (new capability).
- Affected code: new repository; no existing app is modified. Adoption in an app
  is a separate change in that app's repository (four lines behind `kDebugMode`).
- Publishing: consumed by git ref, with
  `dependency_overrides` by path during local development.
