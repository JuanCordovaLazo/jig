# Proposal

## Why

A real app surveyed for this project had 76 `IconButton`s with no label and roughly
8 keys. Any harness that selects by label cannot name those controls at all, and
nothing in `jig` says so: the agent discovers it one failed tap at a time. That
semantics debt is the largest measured cause of unusable selectors, and it is
application-side, so the harness can only make it visible.

## What Changes

- Add an `audit` CLI verb that reads the full element listing and reports the
  accessibility debt in one pass, with a severity per finding.
- Report three findings: a control that cannot be named stably at all, a control
  that can be tapped by key but is invisible to a screen reader, and a label shared
  by more than one control (which makes `--sem` ambiguous).
- Add `--strict`, which exits `1` when any finding is severe enough to be an error,
  so the verb can be used as a gate.

Out of scope: fixing any app's semantics, changing `tree`, and any new VM service
extension - `audit` is computed from the listing that already exists.

## Capabilities

None. No requirement in `agent-harness` changes: this reads existing contract data
and reports on it, so the change sets `skip_specs: true`.

## Impact

- New `packages/jig_cli/lib/src/audit.dart` (pure function) and one dispatch case.
- New unit tests in `packages/jig_cli/test`.
- `README.md` / CLI usage text: one new verb line.
- The verb count goes from fifteen to sixteen, which `CONTRIBUTING.md` treats as a
  contract cost. It is paid here because the debt it reports is the measured reason
  the selector surface is unusable, and because it needs no new extension.
