# Proposal

## Why

`HANDOFF` has listed `jig_mcp` as pending since the bootstrap, and the reason it
matters is in the package table: the driver exists separately from the CLI so an MCP
server can share it instead of scraping stdout. An agent runtime that speaks MCP can
then drive an app through the same verbs, without a shell and without parsing prose.

## What Changes

- Add `packages/jig_mcp`: a Model Context Protocol server over stdio, built on
  `JigVerbs`, with one tool per verb.
- Report app-side failures as MCP tool errors (`isError: true`) carrying the jig error
  JSON, never as successful text. A tool that answers "done" for a failed tap is the
  same defect as a CLI that exits 0.
- Serve `scenarios` through the existing runner, so an MCP client can run a scenario
  file without a second process.

Out of scope: HTTP/SSE transport, resources, prompts, sampling, and any new VM service
extension - the server is another client of the ten that exist.

## Capabilities

None. `skip_specs: true`.

## Impact

- New `packages/jig_mcp` (protocol framing, server, stdio entry point).
- `pubspec.yaml` workspace list, `tool/verify.sh` and `ci.yml` gain the new suite.
- Docs: README package table and a usage block; HANDOFF state row.
