# Design

## Context

See proposal.md. `JigActions.tap`, `typeText`, `swipe`, `scrollUntil`, `back` and
`isPresent` are static methods that work in any isolate where the app is running, and
`JigStateRegistry.snapshot` reads the readers. None of them need a VM service, which is
why an in-process export is possible at all.

## Decisions

1. **The exported test calls `JigActions`, not `WidgetTester` finders.** A generated
   `tester.tap(find.byKey(...))` would be a different harness with different semantics -
   the exact substitution this project exists to argue against. Calling the verbs keeps
   one implementation of "act on an element" and makes the exported test fail for the
   same reasons the CLI does.

2. **The generated file is self-contained.** It carries its own `_drive` and
   `_pumpUntil` helpers instead of importing the fixture's test support: a generated
   artifact must compile wherever it is dropped, and depending on a test-only package
   would tie it to this repository.

3. **A step with no in-process equivalent fails the export.** `ping`, `tree`, `events`
   and `nav` are diagnostics about a *session*; there is no session inside the test. A
   comment in place of the step would be a test that claims to check them.

4. **`--entry` is required.** The exporter cannot know how an app boots; guessing
   `main.dart` would break on any project with more than one entry point, and the import
   is one flag.

5. **`wait` becomes a frame budget, not a clock.** The scenario's `timeoutMs` is divided
   by 16 to get a maximum number of pumps, so the exported test never blocks on wall
   time and a hung app fails instead of hanging CI.
