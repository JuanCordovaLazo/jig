# Proposal

## Why

Two verbs an agent loop needs are missing, and both absences force workarounds that
mislead.

An agent that cannot see the app cannot tell a render bug from a selector bug.
`tree` reports the accessibility tree, which is precisely the tree that omits what a
screenshot shows. Today the only routes to pixels are `flutter screenshot` against a
device the harness does not own, or a helper the app registers for `eval` - and
`eval` returning an image is a data URL the caller has to decode by hand.

Clearing a field is spelled `type --value ''`, which reports `ok` without reading
the field back. Every other verb refuses to claim an effect it did not observe
(`BACK_REFUSED`, `GESTURE_NO_EFFECT`, `SCROLL_EXHAUSTED`); clearing is the one place
where a formatter, an input mask or a controller that rejects the change keeps text
in the field and the command still says success.

## What Changes

- Add `screenshot`: capture the app's rendered frame as PNG from inside the isolate
  and report `file`, `width`, `height`, `bytes`, `pixelRatio`. `-o/--out <path>`
  picks the file (default `.jig/screenshot-<seq>.png`); `--pixel-ratio <n>`
  (default `1`) picks the scale.
- Add `clear`: empty an editable field and fail `CLEAR_REFUSED` when the app keeps
  text in it, naming what is left.
- `type` with an empty `--value` becomes a usage error pointing at `clear`, so one
  action has one spelling.
- Recorder writes `clear` steps; the scenario runner and exported integration tests
  replay them.
- MCP gains `screenshot`, which returns an `image` content block so a model can look
  at the app, and `clear`.
- New protocol error code `CLEAR_REFUSED`.
- `screenshot` is an eleventh VM service extension: pixels are a new capability, not
  another way to act on an element. `clear` rides the existing `type` extension,
  the way `swipe` rides `tap`.
- `apps/fixture/.vscode/mcp.json` wires the fixture to the MCP server at project
  scope, as the worked example the README describes.

Out of scope: element-only captures, video, and screenshot steps inside scenarios.

## Capabilities

No spec-level change. `openspec/specs/agent-harness` was created under
`skip_specs`, and every change since has followed that convention.

## Impact

`jig_protocol` (error code), `jig_flutter` (`clearText`, `screenshot`, eleventh
extension), `jig_driver` (`JigVerbs`), `jig_cli` (two verbs, recorder, runner,
exporter), `jig_mcp` (two tools, image content), `apps/fixture` (state reader,
matrix rows, `.vscode/mcp.json`), `README.md`, `docs/CONTRACT.md`,
`docs/fixture-matrix.md`.
