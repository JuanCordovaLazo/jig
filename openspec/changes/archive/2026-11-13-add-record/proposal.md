# Proposal

## Why

`jig run` can replay a scenario, but writing one by hand means transcribing work
that already happened: an agent taps, types and scrolls its way through a flow, then
rewrites it as JSON from memory. Transcribed steps are where a scenario quietly
diverges from the flow it claims to check.

## What Changes

- Add `jig record --since <seq> --out <file>`: reads the verb events the app already
  emits and writes them as a runnable scenario.
- Emit the selector structurally in those events. The current payload carries only
  `describe()`, a sentence built for error messages; parsing it back would be
  guesswork, and a recorder that guesses writes broken scenarios.
- Refuse to emit a step whose event has no structured selector, and say how many were
  skipped instead of dropping them silently.

Out of scope: recording state assertions (an event log cannot know what the caller
intended to assert) and a long-lived recording daemon.

## Capabilities

None. `skip_specs: true`.

## Impact

- `jig_flutter`: one added field on the verb event, no shape change to the rest.
- `jig_cli`: `packages/jig_cli/lib/src/recorder.dart`, one dispatch case, usage text.
- `packages/jig_cli/test/recorder_test.dart`; `README.md`; verb count docs.
