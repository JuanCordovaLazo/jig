# Tasks

## 1. Fixture: the cases the harness must reach

The fixture is the verification medium for every group below, so it comes first:
each case has to exist before a verb can be shown to handle it.

- [x] 1.1 Add a sliver scroll screen (`CustomScrollView` + `SliverList`) with a
      keyed target near the end. Verify it renders and that `jig tree` does not
      list the target before any paging happens.
- [x] 1.2 Add a nested-scrollable screen (`SingleChildScrollView` containing a
      `ListView.builder`) with keyed inner and outer targets. Verify both
      scrollables are discoverable and the inner target is absent from
      `jig tree`.
- [x] 1.3 Add a `TabBarView` screen with a keyed target on the second tab.
      Verify the target is absent before paging and present after the tab change.
- [x] 1.4 Add icon-only `IconButton`s (leading and trailing actions) to a fixture
      screen. Verify `jig tree` lists them with an empty label, which is the
      condition the metadata work in group 3 has to fix.
- [x] 1.5 Add a double-back gate screen using `PopScope` that shows a
      confirmation instead of popping. Verify the first system back does not
      leave the route and the second (after confirming) does.
- [x] 1.6 Add a stacked-dialogs screen where a `Get.dialog` returns a value that
      lands in a registered state reader. Verify `jig snapshot` shows the value
      after the dialog is dismissed.
- [x] 1.7 Add a `RefreshIndicator` screen. Verify it renders and that its
      refresh action is not reachable by any current verb - this row is expected
      to stay red until gestures exist.
- [x] 1.8 Add `flutter_slidable` to `apps/fixture/pubspec.yaml` and build a
      swipe-to-reveal screen. Verify `pub get` resolves and that the revealed
      action buttons are absent from `jig tree` until a swipe occurs - expected
      to stay red until gestures exist.
- [x] 1.9 Extend `docs/fixture-matrix.md` with the new rows, each carrying the
      command that proves it. Verify every command in the table is copy-pasteable
      and produces the described outcome.

## 2. Protocol: element metadata

- [x] 2.1 Add `key`, `ownerType` and `rect` to `JigElement`, including the
      `toJson`/`fromJson` pair. Verify with a round-trip unit test in a new
      `packages/jig_protocol/test/` directory, and confirm `dart test` passes
      from that package.
- [x] 2.2 Add `rect` as a serialisable value object with `x`, `y`, `width` and
      `height`. Verify the round-trip test covers omitted versus present bounds.
- [x] 2.3 Document the new element shape in `docs/CONTRACT.md` and state that
      bounds are informational and never accepted as input. Verify the documented
      JSON matches a real `jig tree` payload from the fixture.

## 3. App-side: make the listing self-sufficient

- [x] 3.1 Build a semantics-node to owning-widget map in one pass over the
      element tree, reusing the `debugSemantics` walk that `tap` already performs.
      Verify `jig tree` on the fixture reports `ownerType: "ListTile"` for a home
      row rather than the `InkWell` inside it.
- [x] 3.2 Populate `key` from the owning widget's key. Verify `jig tree` reports
      `key: "nav_/overlays"` and that `jig tap --key 'nav_/overlays'` still
      navigates.
- [x] 3.3 Report no key when the owning node is merged into a parent, rather than
      a key from an ancestor. Verify with a `ListTile` that has no key of its own:
      the listing shows `ownerType` but no `key`.
- [x] 3.4 Populate `rect` from the semantics node bounds. Verify the reported
      bounds of a known element agree with its on-screen position at two different
      scroll offsets, and that no command accepts them.
- [x] 3.5 Report `ownerType` for elements with no label. Verify the icon-only
      buttons from task 1.4 are addressable as
      `jig tap --type IconButton --index N`.

## 4. Back

- [x] 4.1 Add `ext.jig.back` implemented through `WidgetsBinding.handlePopRoute`.
      Verify popping a pushed route reports that a pop occurred and
      `jig state route` reflects the route underneath.
- [x] 4.2 Report a typed refusal when nothing consumed the pop. Verify against
      the double-back gate from task 1.5: the first back reports a refusal, not a
      success.
- [x] 4.3 Dismiss stacked modals in framework order. Verify that with a dialog and
      a sheet open, each `back` removes exactly one and the route survives both.
- [x] 4.4 Add the `back` verb to the CLI and its row to `docs/CONTRACT.md`.
      Verify the documented command works as written and that a failed pop exits
      with code 1 and a typed error code.

## 5. Scroll

- [x] 5.1 Add `ext.jig.scroll` with an axis and a step budget, paging the
      scrollable's own accessibility scroll action from inside the UI isolate.
      Verify `--until item_450` on the existing 500-row list returns a handle and
      that a following `tap --ref` acts on the right row.
- [x] 5.2 Add typed exhaustion that lists the rendered rows and names the budget.
      Verify `--until item_99999` fails with an exhaustion error and exits 1.
- [x] 5.3 Distinguish a stall from exhaustion: no change in the rendered set after
      a step means the content ended. Verify on the 500-row list by paging past the
      end with a large budget.
- [x] 5.4 Add `--in` to name the scrollable, and report ambiguity when two exist
      and neither is named. Verify on the nested screen from task 1.2: unnamed
      fails with candidates, `--in` succeeds for inner and outer separately.
- [x] 5.5 Support the horizontal axis. Verify on the `TabBarView` screen from
      task 1.3.
- [x] 5.6 Short-circuit to a single step when the target is already rendered.
      Verify the reported step count is 1 for a visible target and that bounds are
      unchanged afterwards.
- [x] 5.7 Do not page when a modal covers the target. Verify that with a dialog
      open, `scroll --until` on a covered row reports the same typed failure as
      `tap` and does not move the list.
- [x] 5.8 Add the `scroll` verb and its flags to the CLI and the row to
      `docs/CONTRACT.md`, including the new exhaustion error code. Verify the
      documented command works as written.

## 6. Integration

- [x] 6.1 Run the full `docs/fixture-matrix.md` on a device and confirm every
      supported row passes and the two gesture rows fail with typed errors.
- [x] 6.2 Confirm `dart analyze .` is clean and `dart test` passes across the
      workspace.
- [x] 6.3 Update the README status table so the verb count, the extension count
      and the remaining gap list match reality.
- [x] 6.4 Confirm the extension count is 10 in both `docs/CONTRACT.md` and the
      code, and that no command has gained a position parameter.

## Workflow follow-up

- Archive `bootstrap-agent-harness` before this change, so `agent-harness` gains
  its requirements in order.
- Archive this change after the fixture matrix is green on a device.
