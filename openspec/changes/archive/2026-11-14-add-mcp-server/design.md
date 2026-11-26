# Design

## Context

See proposal.md. `JigVerbs` in `jig_driver` is the verb set without a transport, and
`JigConnection` is its real implementation. `JigScenario` and `JigRunner` in `jig_cli`
already turn a scenario into a sequence of those calls.

## Decisions

1. **Hand-rolled JSON-RPC framing, no new dependency.** MCP over stdio is
   newline-delimited JSON-RPC 2.0: a `initialize`, a `tools/list`, a `tools/call`, and
   notifications. Writing it is a hundred lines and keeps the dependency surface of a
   tool that runs inside other people's editors at zero. A library would have been the
   right call for anything with more surface.

2. **The server depends on `JigVerbs`, not on `JigConnection`.** Same reason the
   runner does: the whole protocol layer is then testable by feeding it messages, with
   no socket and no app. The stdio entry point is the only place that dials.

3. **A tool failure is an MCP error result, not a thrown exception.** MCP distinguishes
   "the tool ran and the thing failed" (`isError: true` with content) from "the request
   was malformed" (a JSON-RPC error). Mapping an app failure to a JSON-RPC error would
   tell the client the server is broken, which is the conflation this project keeps
   removing.

4. **Tool names are the verb names.** An agent that read the CLI docs can guess the
   tool, and the two surfaces stay comparable. `scenarios` is the one exception: the
   tool is `run_scenario` because it takes a path, not a selector.

5. **`initialize` answers with a version the client supports, or refuses clearly.** If
   the client asks for one we implement, we echo it; otherwise the response carries our
   own version and the client can decide. Echoing an arbitrary requested version would
   claim support we have not tested, and refusing outright would break on any client we
   have not seen.
