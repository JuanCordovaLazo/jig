# Design

## Context

See proposal.md. `swipe` emits a real pointer path and refuses to report success
unless something observable changed. Row 20's screen currently satisfies neither half
of that second requirement: its `onRefresh` awaits a delay and records nothing.

## Decisions

1. **The counter is a controller, not a local `setState`.** Every other observable
   thing in the fixture is a `GetXController` read through `Jig.state`, and a page's
   private field would need the harness to reach into the widget tree - which is
   exactly what named readers exist to avoid. `RefreshController` also makes the
   *first* refresh observable, not just "something changed".

2. **The fixture change is the honest fix, not a workaround.** Recording that a
   refresh happened does not make a failing refresh pass: it makes a silent one
   visible. A gesture that does not reach the indicator still leaves the counter at
   zero, and the test asserts that number rather than the absence of an exception.

3. **The swipe starts inside the list, not at the page.** Pull-to-refresh needs an
   overscroll while the scroll position is at the top, and the drag has to be
   vertical. Targeting the first row with `--direction down` satisfies both without
   adding an anchor option: the geometry still comes from the element, and the
   gesture is expressed the way a user produces it.
