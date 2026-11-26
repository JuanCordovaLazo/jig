# Proposal

## Why

An agent driving the fixture through the MCP looked for the swipe-actions screen with
`tree q: "slid"` and was told nothing matched. The tile was on screen the whole time; its
label is "Swipe actions" and its key is `nav_/slidable`. The filter searched labels and
values only, so a caller who already knew the key it wanted had no way to ask.

That is the worst shape of a discovery bug: the answer is present, the query is reasonable,
and the empty result reads as "this does not exist here". The agent reported the route as
unreachable, which is a wrong conclusion drawn from a correct observation.

## What Changes

- `ext.jig.elements` includes the element's key in the `q` haystack, next to label and value.
- The three places that describe `q` - the CLI help, the README table and the MCP tool schema
  - say "key, label or value" instead of "label or value".
- `packages/jig_flutter/test/elements_diag_test.dart` asserts that a key matches, that a
  label still matches, and that a real miss still returns nothing.

Out of scope: matching on `ownerType` or on the ref. A key is stable and typed by the caller;
a ref is a handle and a type is a last resort, so neither is what "find this thing" means.

## Capabilities

No spec-level change: `q` was always described as a filter, and its scope is a detail of the
filter rather than a requirement about addressing. `skip_specs: true`.

## Impact

`packages/jig_flutter` (one predicate, one test), `packages/jig_cli` and `packages/jig_mcp`
(help text only), `README.md`.
