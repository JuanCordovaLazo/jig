# Design

## Follow the CLI's precedence instead of inventing a second one

The server is a second entry point into the same session, so "which URI wins" must have one
answer. `resolveServerUri` mirrors `_connect` in the CLI exactly - flag, environment,
session file - and the tests state each step, including the two cases that look trivial and
are not: an empty `--uri ""` must not shadow the environment, and an unset variable must
yield null rather than an empty string that would later look like a connection to nowhere.

The function lives in the library rather than the bin so it can be tested. A bin is only
reachable by spawning a process; the precedence is the part that can regress, and it is
three lines that now have five tests.

## `$JIG_URI` is not a convenience here

In a shell, typing `--uri` is fine. In `.mcp.json` it is not: the format forbids `inputs`,
and the workspace-root form has no prompt, so an environment reference is the only channel
a portable config has for a value that changes per launch. Supporting it in the CLI and not
in the server made the documented portable snippet silently unable to point at an app -
the failure being a `NOT_CONNECTED` that looks like "the app is not running".

## No root-level `.mcp.json`

A workspace-root file is read from the root of the folder that is opened. Adding one at the
repository root would help exactly one case - opening the monorepo - and it would need
`cwd` to point discovery at `apps/fixture`. `cwd` is a documented field but absent from VS
Code's form and unmeasured here, so the file would be a guess. The README names it as
something to try, labelled as unverified, and keeps the measured path primary.

## `tools: ["*"]` stays, and is described accurately

It selects which tools the server exposes; it does not bypass approvals. Being explicit
about that matters because the surrounding paragraph warns that this server has no
sandbox - a reader who believes `["*"]` auto-approves would draw the wrong conclusion about
the configuration either way.
