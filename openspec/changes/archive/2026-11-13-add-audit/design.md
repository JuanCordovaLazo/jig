# Design

## Context

See proposal.md. `tree --all` already returns every semantics node that carries a
label, value or action, each with `ref`, `label`, `key`, `ownerType` and `actions`.
Everything `audit` needs is in that payload, so the question is only where the
judgement lives.

## Decisions

1. **No eleventh extension.** `audit` composes the existing `elements` extension and
   decides nothing the app has to participate in. The ten-extension budget is the
   contract cost that `CONTRIBUTING.md` protects, and this feature can be paid for
   without touching it. The cost it does pay is a sixteenth CLI verb, which is
   cheap: verbs are composable, extensions are not.

2. **The auditor is a pure function over `List<JigElement>`.** It lives in
   `jig_cli/lib/src/audit.dart` and returns findings, so it is unit-tested without a
   VM service or a widget. It deliberately does **not** go into `jig_protocol` yet:
   nothing but the CLI consumes it, and putting it in the published contract to
   serve a package that does not exist would freeze an API before it has a second
   caller. If `jig_mcp` later needs it, it moves then and the move is cheap because
   the function has no I/O.

3. **Three findings, defined by what the caller can actually do.** Severity is not
   about the screen reader alone; it is about whether a selector exists:
   - `unaddressable` (**error**): interactive, no label, no key. The only handle is
     widget type plus index, which breaks as soon as the screen changes.
   - `unlabelled` (**warn**): interactive, no label, but a key exists. Selectable
     and unreadable: accessibility debt, not a harness blocker.
   - `ambiguous` (**warn**): two or more interactive elements normalise to the same
     label, so `--sem` resolves to one of them silently.
   Labels are normalised the same way matching normalises them, so the ambiguity
   reported is the ambiguity a selector will actually hit.

4. **`--strict` turns the report into a gate.** Without it the verb exits `0`
   whatever it finds, because a report that fails the shell is a report people stop
   running. With it, any `error` finding exits `1`, which is the documented
   "command failed" code and not a new one.
