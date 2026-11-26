# Proposal

## Why

A scenario only runs where `jig` and a VM service are. Teams that gate merges on
`flutter test integration_test/` cannot use one, so the choice is between a harness
with a gate of its own and the CI they already have. Exporting a scenario as an
`integration_test` file removes that choice without reimplementing anything: the
exported test calls the same `JigActions` the CLI drives.

## What Changes

- Add `jig export --scenario <file> --out <file> --entry <package import>`: writes a
  Dart `integration_test` that replays the scenario's acting steps and state
  assertions against `JigActions` and `JigStateRegistry`.
- Refuse to export a step that has no in-process equivalent, and name it. Dropping
  `events` or `tree` silently would produce a test that passes while checking less
  than the scenario.
- Commit one exported file under `apps/fixture/integration_test/` so `flutter analyze`
  keeps it compiling, which is the only way an exporter stays honest between runs.

Out of scope: running the exported test here (needs a device), exporting `record`
output automatically, and any change to `jig_flutter`'s runtime.

## Capabilities

None. `skip_specs: true`.

## Impact

- `packages/jig_cli/lib/src/exporter.dart` plus one dispatch case.
- `apps/fixture`: `integration_test` as a dev dependency, one exported example.
- Docs: README and HANDOFF verb counts and queue.
