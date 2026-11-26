# Design

See `proposal.md` for why this change is needed and the measured gap it closes.

## Context

The harness acts by resolving a selector to a semantics node and calling
`SemanticsOwner.performAction`, never by dispatching a pointer at a coordinate
(D1, D2 in `bootstrap-agent-harness`). That decision is what the whole change has
to work within: a scroll method that synthesises a drag would be a coordinate
gesture in disguise.

The semantics tree only contains what is rendered, so the harness can see exactly
one viewport. Everything outside it is invisible and unreachable - including
control that exists in the widget tree but is covered by a modal, which is the
behaviour rows 1 and 3 of `docs/fixture-matrix.md` already pin down.

Two properties of the framework make the reach problem tractable:

- a scrollable advertises its own `SemanticsAction.scrollUp` / `scrollDown` /
  `scrollLeft` / `scrollRight`, and performing it pages the scrollable exactly as
  a screen reader would;
- `WidgetsBinding.handlePopRoute()` is the entry point the platform back button
  uses, so routing through it inherits `PopScope`, `canPop` and modal dismissal.

`JigElement` currently reports `ref`, `kind`, `label`, `value`, `hint`, `actions`
and `depth`. `key` is declared but never populated, and there is no owning-widget
type and no bounds, so a caller reading a listing cannot use the selectors the
contract ranks first and third.

## Goals / Non-Goals

**Goals:**

- Reach an element that is not rendered, without the caller computing pixels and
  without the host round-tripping a page loop.
- Leave a route, a dialog or a sheet, through the app's own navigation policy.
- Make the listing self-sufficient: what a caller sees is what a caller can select
  with.
- Keep the extension surface at 10 and keep the cost of an unreached target typed
  and explainable.

**Non-Goals:**

- Drag, swipe, pull-to-refresh, or any gesture whose semantics is a pointer path.
  `RefreshIndicator` and `slidable` stay unsupported; the fixture documents them
  as failing rows rather than hiding them.
- Infinite scroll triggered by reaching the end of a list (loading more data).
  Paging stops at content exhaustion; whether the app then fetches more is the
  app's behaviour, observable through `events`.
- Determinism for CI. This change makes the new verbs deterministic in shape - see
  D4 - but does not add scenario execution, artefacts, or parallel sessions.

## Decisions

### D1 - Page with the scrollable's own semantics action, not with a drag

The scrollable node advertises `scrollUp`/`scrollDown`/`scrollLeft`/`scrollRight`.
Performing that action is the accessibility-native page, it is unaffected by
nesting depth, and it cannot land on the wrong widget because it carries no
position.

Rejected: synthesising a drag with `GestureBinding`. It reintroduces the exact
failure mode D2 of the bootstrap change removed, and it cannot distinguish "the
scroll happened" from "the pointer was absorbed by an overlay".

Rejected: `ScrollPosition.jumpTo` by pixel offset. It requires knowing the target's
offset, which for a lazily built list means knowing its index and extent - the
caller would be doing arithmetic the harness exists to remove.

### D2 - The page loop runs inside the UI isolate

`ext.jig.scroll` takes the selector, the axis and a step budget, and returns only
when the target appears or the budget is spent. Each iteration: perform the scroll
action, wait one frame, re-read the tree, test the selector.

Rejected: a `scroll --dy` primitive the host calls in a loop. Twenty round trips
is twenty chances for a caller to misread state in between, which is the ad-hoc
script pattern this project replaces. It also makes the exhaustion decision
ambiguous - the host would decide when to stop, using state it read earlier.

The step budget is a parameter, not a constant, because the right number depends
on list length. The default is conservative and the typed exhaustion error names
the budget so a caller can raise it deliberately.

### D3 - Nested scrollables are disambiguated by the caller, never guessed

With two scrollables, paging the wrong one either does nothing observable or
scrolls the outer one and loses the inner position. Taking the first scrollable
found would be a guess that usually works and sometimes silently does not.

`--in <selector>` names the scrollable. Without it, the app-side code pages the
nearest scrollable ancestor of the target *if the target is already rendered*
(then `ensureVisible` handles it in one step), and otherwise reports
`ELEMENT_AMBIGUOUS` with the candidate scrollables. If there is exactly one
scrollable in the tree, that is unambiguous and is used without asking.

### D4 - Every step is bounded and every failure is typed

The loop has three exits: found, budget exhausted, axis stalled - the last meaning
the scroll action produced no change in the rendered rows, which is how a list at
its end behaves. All three are reported distinctly. A run that reaches the end of
the content is not an error; a run that finds nothing is.

This is what keeps the verb deterministic in shape even though CI execution is out
of scope: given the same tree and the same budget, the outcome is the same, and
the failure says which of the three exits fired.

### D5 - `back` routes through `handlePopRoute()`

`WidgetsBinding.instance.handlePopRoute()` is what the platform back button
dispatches. Using it means `PopScope`/`canPop` are honoured, stacked modals are
dismissed by the framework's own ordering, and a `DoubleBackExitGate`-style
interception behaves exactly as it does for a user.

Rejected: `Navigator.pop()` directly. It bypasses `PopScope`, so a screen that
guards unsaved changes would be popped anyway - a test that passes while the real
button would not.

Rejected: `Get.back()`. It couples the harness to GetX, which `jig_flutter`
deliberately does not depend on.

The operation reports whether a route actually left the stack. `handlePopRoute`
alone is not enough: a route that refuses the pop still answers `true`
(`RoutePopDisposition.doNotPop`), which is why the refusal is detected by watching
the navigator observer's removal count across the request. Reporting that as
success would be the silent no-op this project exists to remove.

### D6 - Element metadata comes from inverting the mapping `tap` already walks

`tap` goes element to semantics node via `renderObject.debugSemantics`. The
listing needs the inverse. One pass over the element tree builds
node-id to (key, owner type) while `SemanticsNode.rect` supplies bounds for free.

Rejected: populating `key` only. For an app with almost no keys it buys nothing,
while the owner type is what makes an unlabelled control selectable at all. They
cost the same pass.

The owner type reported is the widget type whose render object owns the node, not
the nearest widget - so a `ListTile` reports as `ListTile` rather than as the
`InkWell` inside it.

### D7 - Bounds are reported, never accepted

`rect` is informational: it lets a caller crop a screenshot, reason about layout,
and read a better error message. It is deliberately not a selector, and no command
gains a position parameter. This preserves the ban stated in the bootstrap change's
D1 and keeps the fixture's overlay rows meaningful.

## Risks / Trade-offs

- **[Paging is slow on long lists]** → the loop is per-frame, so a target 400 rows
  down costs hundreds of frames. Mitigation: the budget is explicit, exhaustion
  lists what is rendered so the caller learns to raise it, and `--in` with
  `ensureVisible` short-circuits the common case where the target is rendered.
- **[Some scrollables do not advertise scroll actions]** → a custom scroll view
  without semantics produces no scrollable node. Mitigation: the typed failure
  names that case, and the fixture's sliver row proves whether `CustomScrollView`
  is among them before any app depends on it.
- **[`debugSemantics` is debug-only]** → acceptable, since the runtime is
  debug-only by design; the alternative is an extension that only works in the
  build nobody tests.
- **[The inverse map can disagree with the node's own label]** → a widget may carry
  a key whose semantics node is merged into a parent. Mitigation: an element
  reports the key of the node's own owner; when the node is merged, no key is
  reported rather than a misleading one.
- **[Two unarchived changes touch the same capability]** → archive
  `bootstrap-agent-harness` before this one, as stated in the proposal.

## Migration Plan

1. Protocol fields first (additive), so the driver and CLI can be written against
   the final element shape.
2. `back` alone - smallest verb, proves the extension budget and the typed refusal.
3. `scroll` with the fixture's long list, then the sliver and nested rows, then the
   horizontal case.
4. Fixture rows for the unsupported gestures, added last and expected to fail, so
   the documented gaps are the final state rather than an interruption.
5. Update `docs/CONTRACT.md`, `docs/fixture-matrix.md` and the README status table
   in the same change, since the extension count is part of the contract.

Rollback is not a concern: the package is at `0.x` and consumed by git ref, so a
consumer pinning a tag is unaffected by anything here.
