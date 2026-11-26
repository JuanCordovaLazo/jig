# Proposal

## Why

`.vscode/mcp.json` is the editor-managed configuration of the deprecated Local harness.
VS Code flags it as obsolete and the Copilot harness does not read it directly, so the
fixture's committed example had become instructions for a file the editor no longer loads.
The portable destination is `.mcp.json` at the workspace root, with a top-level
`mcpServers` object.

Migrating exposed a real gap: the portable format has no `inputs`, so a URI that changes on
every launch has to travel through the environment. The CLI already honours `$JIG_URI`, but
`jig_mcp` did not - it only knew `--uri` and session discovery. Two entry points resolving
the same connection differently is exactly the class of defect this project tracks.

## What Changes

- `apps/fixture/.mcp.json` replaces `apps/fixture/.vscode/mcp.json`, in the `mcpServers`
  format.
- `jig_mcp` resolves its target like the CLI does: `--uri`, then `$JIG_URI`, then the
  nearest `.jig/session.json`. New `resolveServerUri` in
  `packages/jig_mcp/lib/src/connect.dart`, with tests for each step of the precedence.
- `.gitignore` drops the `.vscode/mcp.json` exception - plain `.vscode/` again - and says
  why `.mcp.json` is deliberately tracked.
- `README.md`'s editor section is rewritten for the portable format: the deprecation, the
  absence of `inputs`, `tools: ["*"]` and what it does not do, the `$JIG_URI` path, and the
  FVM variant.

Out of scope: any root-level `.mcp.json`. The file has to sit at the root of the workspace
that is opened, and `apps/fixture` is the app an agent would drive.

## Capabilities

No spec-level change; the verb surface is identical. `skip_specs: true`.

## Impact

`apps/fixture`, `packages/jig_mcp` (one new file, one bin line, five tests), `.gitignore`,
`README.md`.
