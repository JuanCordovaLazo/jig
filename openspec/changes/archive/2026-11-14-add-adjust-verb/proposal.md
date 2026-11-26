# Proposal

## Why

A slider advertises `increase` and `decrease` and never `tap`. Before this change the
fixture's rating slider was unactable: `tap` requires a `tap` action, `type` needs editable
text, and `swipe` needs a pointer path that produces an observable change. The one control an
agent could see in `tree` - `_SliderRenderObjectWidget`, value `60%`, actions
`[increase, decrease, focus]` - it could not move.

That is a hole in the verb set, not a fixture quirk: any range control in any app had it.

## What Changes

- New verb `adjust`: `--direction up|down` (default `up`) and `--times <n>` (default 1). It
  applies that many steps, reads the value back, and reports `previousValue`, `value` and
  `steps`.
- New code `ADJUST_REFUSED`, for three situations the messages distinguish: the control
  exposes no steps, it is already at that end, or the value did not move.
- It rides the existing `ext.jig.tap` extension as `action=increase|decrease&times=n`. No
  twelfth extension: the wire already means "perform a semantics action on an element", and
  `long` was already selecting a different action.
- `adjust` is a scenario step, a recorded verb and an exported `JigActions.adjust` call, and
  an MCP tool.
- `packages/jig_flutter` learns to find a range control whose key sits on a wrapper: the
  semantics node belongs to a render object *below* the keyed widget, so the lookup searches
  down as well as up. `tap` keeps looking up only, deliberately.
- The fixture gains `FormController.rating` and the `form.rating` reader, so a scenario can
  assert the value a step produced.

Out of scope: a stepper made of `+`/`-` buttons, which is two `tap`s and needs no verb; and
the pre-existing `find --key` attribution gap, recorded in `docs/HANDOFF.md` as its own
design decision.

## Capabilities

No spec-level change: every requirement is about how an element is addressed and acted on,
and `adjust` adds a verb without changing either. `skip_specs: true`.

## Impact

`jig_protocol` (one code), `jig_flutter` (`JigActions.adjust`, the downward lookup, the
extension branch), `jig_driver`, `jig_cli` (verb, scenario, runner, recorder, exporter),
`jig_mcp` (one tool), `apps/fixture` (controller, reader, one test file), docs.
