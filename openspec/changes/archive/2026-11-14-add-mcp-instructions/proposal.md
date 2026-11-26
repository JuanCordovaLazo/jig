# Proposal

## Why

A tool description can explain one verb. Nothing in the protocol let the server say how the
verbs compare, and the consequence was measurable: `screenshot` was described in the same
register as `tree`, so "what is on screen?" had no signal pointing at the cheaper, exact,
assertable answer. The only hint that existed was one sentence inside `tap`'s description -
in the one place a caller who is about to take a screenshot will never read.

MCP has a field for exactly this: `initialize` returns `instructions`, described as
instructions for the client to put in front of the model. This server never sent it.

## What Changes

- `JigMcpServer.instructions` - a short playbook, sent in the `initialize` result. It ranks
  the tools by cost (`state`/`events`/`nav`, then `tree`, then the acting verbs, then
  `screenshot`), states what `screenshot` is and is not for, and names the error each
  failure produces and the ref lifetime.
- `screenshot`'s own description points at the cheaper tools, for the case where a model
  reads descriptions and not the playbook.
- `packages/jig_mcp/test/instructions_test.dart` guards it: `initialize` carries it, the
  ranking survives, the "not for locating an element" sentence survives, and every name it
  mentions is a tool that exists or a `JigErrorCode` that is defined.

Out of scope: teaching a client to display it. `instructions` is spec'd and sent; whether a
host shows it is the host's business.

## Capabilities

No spec-level change; no verb changes behaviour. `skip_specs: true`.

## Impact

`packages/jig_mcp` (the constant, the initialize result, one test file), `README.md`,
`docs/CONTRACT.md`. The initialize reply grows by ~1.5 KB, paid once per connection.
