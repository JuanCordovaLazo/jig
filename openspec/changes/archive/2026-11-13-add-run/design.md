# Design

## Context

See proposal.md. The verbs already exist as methods on `JigConnection`, each returning
a `JigResponse`. `audit` established the precedent for a CLI-side verb that composes
existing extensions rather than adding an eleventh one.

## Decisions

1. **The runner is testable through an interface, not through a socket.** `JigVerbs`
   lives in `jig_driver` and `JigConnection` implements it; the runner depends on the
   interface. The alternative - testing the runner via an unreachable URI - would only
   ever exercise the failure path, and a runner whose happy path is untested is a
   runner nobody can trust. The interface belongs in the driver because the driver
   owns the verb contract; `jig_cli` merely orchestrates it.

2. **JSON, not YAML.** A scenario is data an agent writes and a machine diffs.
   `dart:convert` is already there; YAML would add a dependency to gain a syntax we do
   not need for a list of steps.

3. **Stop at the first failure, and say so for the rest.** Steps after a failure are
   reported as `skipped`, not omitted: a report that silently ends early looks like a
   short scenario. The exit code is `1`, which is already the documented "command
   failed".

4. **`expect` lives on the `state` step.** Assertions about what the app shows are
   already covered by acting verbs failing loudly; what needs an explicit assertion is
   registered state, which no verb otherwise inspects. Keeping it on `state` avoids a
   second verb whose only job is to read the same extension.

5. **A mismatch has its own code.** `EXPECTATION_FAILED` distinguishes "the app did
   something else" from `INTERNAL` ("jig broke") and from `TIMEOUT` ("it never
   happened"). Collapsing those is how a scenario becomes a coin flip to debug.
