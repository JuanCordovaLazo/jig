# Design

## Context

See proposal.md. `JigActions` already emits one event per acting verb through
`_record(verb, selector, ref:)`, with the payload `{selector: describe(), ref}`. The
bus keeps a bounded ring with monotonic `seq`, so `events --since` can window it.

## Decisions

1. **Add a field, do not reshape the old one.** `selector` stays the human sentence it
   always was, because error messages and existing consumers read it. The structured
   form arrives beside it as `selectorSpec` (`JigSelector.toJson`, which already
   round-trips). Additive changes are minor; a rename would be major for no gain.

2. **A recorder needs no daemon.** The events are already buffered in the app, so
   `record --since` reads what happened and writes a file. A recording daemon would
   add a second process, a lifecycle, and a failure mode, to save one flag.

3. **An unrecordable event is reported, not invented.** An event from a runtime that
   predates `selectorSpec` cannot become a step; converting `describe()` back with a
   regex would produce a selector that might not match what was tapped. Those are
   counted and surfaced as `skippedEvents`, so a short scenario is explained.

4. **Assertions are not recorded.** Only the caller knows what should be true
   afterwards; guessing an expectation from the state at record time would bake in
   today's values and turn a check into a tautology. The recorded scenario is a
   starting point that the caller then asserts in.
