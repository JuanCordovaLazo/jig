# Proposal

## Why

The MCP tool list is the whole manual an agent gets. A client hands `name`,
`description` and `inputSchema` to a model and nothing else reaches it - not this README,
not `docs/CONTRACT.md`, not the CLI's `--help`. Dumping the published payload showed the
list had been written as if a human would read it beside the docs: `tap` was "Activate an
element", every argument was "a11y label" or "widget key", no failure mode was named, and
three mandatory facts were simply absent:

- `tap` did not declare `ref` or `long`, though its handler accepts both;
- `tap`, `type`, `clear`, `wait`, `swipe` and `scroll` did not say a selector is required,
  so a schema-valid call with no arguments was rejected only after the fact;
- `scroll.axis` and `events.sources` were free strings while the code accepts a closed set.

A model working from that list guesses, and guessing is the failure this project exists to
remove - the same defect as a verb that reports an effect it did not observe, moved one
layer out.

## What Changes

- Every tool description states what the verb does, what it needs, what comes back and the
  error a caller will hit.
- Every argument carries a description that says how to choose it; closed sets are `enum`s.
- The selector constraint travels as `anyOf` over the four spellings - or five for `tap`,
  which also accepts a ref - because "one of" is not expressible with `required`.
- `tap` gains `ref` and `long`; `type` declares `value` as required.
- `packages/jig_mcp/test/tools_contract_test.dart` enforces all of it: description length,
  documented arguments, the one-of arms, the enums, the declared mandatory argument, and
  the named failure mode per verb.
- `README.md` stops claiming "one tool per verb" - it is thirteen tools, and the shell
  verbs are deliberately not among them - and `docs/CONTRACT.md` gains the rule.

Out of scope: new tools. This changes what the existing ones say, not what they do.

## Capabilities

No spec-level change; the verb surface is identical. `skip_specs: true`.

## Impact

`packages/jig_mcp` (tool definitions, one new test file), `README.md`, `docs/CONTRACT.md`.
The published `tools/list` grows from 8.6 KB to 12 KB of prose - about 3k tokens, paid once
per session, in exchange for fewer round trips spent guessing.
