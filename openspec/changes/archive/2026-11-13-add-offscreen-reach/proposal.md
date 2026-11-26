# Proposal

## Why

`jig` can observe an app and act on what is visible, but it cannot complete a real
flow: nothing below the fold is reachable and there is no way to go back. This is
not a hypothetical - it is the current state of `docs/fixture-matrix.md`, whose row
9 documents off-screen reach as a deliberate failure.

Measured against the app this is built for (a large production Flutter app, 238
files under `lib/presentation`), the shapes that break are the common ones:

| Pattern | Sites | Reachable today |
|---|---|---|
| `SingleChildScrollView` | 51 | partial - only what fits |
| `ListView.builder` | 21 | no - items are not built |
| `CustomScrollView` (slivers) | 4 | no |
| Scrollable nested inside a scrollable | 3 confirmed | no |
| `TabBarView` | 1 | no - wrong axis |
| `IconButton` without a label | 76 | no - no semantics at all |
| `Key` of any kind | ~8 | not reported by `elements` |

The last two rows compound. `docs/CONTRACT.md` ranks `key` as the most stable
selector and `semantic` second, but `JigElement` never populates `key`, never
reports the owning widget type, and never reports a rect. So an agent that reads
`jig tree` sees labels only, and labels are exactly what 76 icon buttons do not
have. The stability ranking exists in the contract and is unusable from the
listing.

The consequence for the team is concrete: the harness works on the fixture and
stalls on the first long screen of a real app, which means the daily scripts it is
meant to replace keep being written.

## What Changes

- **`back`** - new verb and `ext.jig.back`, implemented through
  `WidgetsBinding.handlePopRoute()`. That is the same path the physical back button
  takes, so `PopScope` and `canPop` are honoured instead of bypassed. It also
  dismisses stacked dialogs, which is how 83 `Get.dialog` sites return.
- **`scroll`** - new verb and `ext.jig.scroll`, with `--until <selector>`. Paging
  happens inside the UI isolate by performing the scrollable's own
  `SemanticsAction` between frames, with a bounded step count, an optional `--in`
  to disambiguate nested scrollables, an axis, and a typed exhaustion error that
  lists what is actually rendered.
- **`elements` reports what a caller selects with** - `key`, `ownerType` and `rect`
  on every element, from one element-tree pass. `rect` comes from
  `SemanticsNode.rect` and costs nothing; `key` and `ownerType` invert the
  element-to-node mapping that `tap` already walks. Without this, `--key` remains
  the number one selector on paper and the number three in practice.
- **The fixture grows to cover the measured cases** - sliver scroll, nested
  scrollables, `TabBarView`, `RefreshIndicator`, `flutter_slidable`, a
  double-back-to-exit gate, icon-only controls, and stacked dialogs that return a
  value. Two of those rows are expected to **fail** (`RefreshIndicator`,
  `slidable`): both need a drag gesture, gestures are out of scope here, and a row
  that fails with a typed error documents the gap better than a row that is absent.
- **The extension surface grows from 8 to 10**, and the contract says so.

## Capabilities

### New Capabilities

None. This change extends behavior the project already claims.

### Modified Capabilities

- `agent-harness`: three requirements are added - navigation control, reach beyond
  the rendered viewport, and element metadata sufficient to select without
  guessing. The existing requirements are unchanged; in particular the ban on
  caller-supplied coordinates and the rule that a gesture which cannot be proven
  to have reached its target is not reported as success both still hold, and the
  scroll implementation is bound by them.

## Impact

- `packages/jig_protocol` - `JigElement` gains `key`, `ownerType` and `rect`.
  Additive, so a minor version.
- `packages/jig_flutter` - `element_index` builds the node-to-element map; new
  scroll paging in `actions`; two extensions; `back` goes through the widgets
  binding.
- `packages/jig_driver` and `packages/jig_cli` - two call wrappers and two verbs,
  `--until`, `--in`, `--axis`, `--steps`.
- `apps/fixture` - eight new rows, each with the command that proves it.
- `docs/CONTRACT.md` - the extension table, and the statement that `rect` is
  informational while positions remain derived and never supplied.
- `docs/fixture-matrix.md` and the README status table.
- Builds on `bootstrap-agent-harness`, which is still in flight: archive that
  change before this one, so the `agent-harness` capability gains its requirements
  in order.
