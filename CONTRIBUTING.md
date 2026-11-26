# Contributing

## Licensing

`jig` is Apache-2.0. By submitting a pull request you agree that your
contribution is licensed under the same terms, as stated in section 5 of the
license. No separate CLA or sign-off is required.

## Before opening a pull request

```bash
./tool/verify.sh
```

That is analysis plus every suite, and it exits non-zero when anything fails. It
runs each step to completion, so one run reports every breakage rather than the
first. It mirrors the `analyze` and `test` jobs in `.github/workflows/ci.yml`; if
you add a suite or a package, add it to both.

To iterate on a single suite, run it directly from its package:
`dart test` in `packages/jig_{protocol,driver,cli}`, `flutter test` in
`packages/jig_flutter` and `apps/fixture`.

## What gets accepted

The project keeps a deliberately small surface: eleven VM service extensions and
twenty-three CLI verbs. A change that adds a twelfth extension or a twenty-fourth verb
needs a reason that outweighs the contract cost, because every one of them is
something the tool must keep working forever.

Rejected on principle:

- a custom `WidgetsBinding` subclass, or anything that replaces the binding
- an overlay, animated indicator or visual effect injected into the app
- a caller-supplied screen coordinate as a selector
- a pointer gesture whose geometry the caller supplies, or one that is not proven
  to have done something: `swipe` derives the path from the target's box, accepts
  only a named direction, hit-tests the origin first, and fails
  `GESTURE_NO_EFFECT` when nothing changes
- a fixed `sleep` in place of a predicate
- a verb that reports an effect it did not observe: `clear` reads the field back and
  fails `CLEAR_REFUSED`, `adjust` reads the value back and fails `ADJUST_REFUSED`, and
  `type` refuses an empty value rather than impersonating it
- a fallback that invokes a widget callback directly when hit-testing fails
- a new dependency in `jig_flutter` on a state management library

## Changing the fixture

`apps/fixture` is a conformance suite, not a demo, and `docs/fixture-matrix.md` is
its index. If you touch a screen, update the matrix row.

Do not fix the bug in `BuggyController`. It is the only end-to-end proof that a
failing flow actually fails; without it, the harness's success criterion degrades
to "the command did not throw".

## Changing the contract

`packages/jig_protocol` is the public API. Adding a field is a minor version;
renaming or removing one is major. Update `docs/CONTRACT.md` in the same pull
request - a contract change that exists only in code is a bug.
