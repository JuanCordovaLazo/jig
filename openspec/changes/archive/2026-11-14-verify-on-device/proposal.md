# Proposal

## Why

Everything up to here was verified in-process, against fakes or the widget binding. That
is where the last several defects hid: a fake that encoded the wrong wire shape passed
while the real app returned something else. Running the whole surface against an Android
emulator - verbs, scenario, record, export, MCP - was the only way to find out what is
actually true.

## What Changes

- Run every verb against a real device, plus a scenario, a recording, an exported
  `integration_test` and the MCP server, and fix what the run exposes.
- Five defects came out of it, each a case of the harness reporting something other than
  what happened:
  - the scenario runner read `data['state']` while the app sends `data['values']`, so
    every `state` assertion failed on a device while the value was plainly there;
  - the recorder dropped `back` silently, because it has no selector;
  - the MCP server never exited after its stdin closed, leaving a hung subprocess;
  - a generated `integration_test` leaked the semantics handle `Jig.install` creates;
  - the example scenarios were not self-contained, so a replay started on the wrong
    route and typed into a field that had not been built yet.
- Make the example scenarios start from home and wait for what they act on, and document
  that as the pattern.
- Make the README match what exists: `jig_mcp` runs, scenarios run, and the milestone
  table says so.

Out of scope: iOS, and any new verb.

## Capabilities

None. `skip_specs: true`.

## Impact

- `packages/jig_cli`: `runner.dart`, `recorder.dart`, `exporter.dart` and their tests.
- `packages/jig_mcp/bin/jig_mcp.dart`.
- `apps/fixture`: example scenarios, regenerated integration test.
- `README.md`, `docs/HANDOFF.md`.
