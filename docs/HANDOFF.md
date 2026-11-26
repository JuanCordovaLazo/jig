# Handoff

Context for whoever picks this up - human or agent. It records what the repository
cannot tell you about itself: why the decisions were made, what was measured, and
which rules are load-bearing.

## What jig is

An agent-driven end-to-end harness for Flutter. It acts through the accessibility
tree rather than by dispatching pointers at coordinates, reads application state
through named readers, and records HTTP exchanges, log lines, navigation
transitions and unhandled errors in a bounded bus with a monotonic sequence.

```
packages/jig_protocol   the wire contract: selectors, elements, events, errors
packages/jig_driver     VM service transport and verbs
packages/jig_flutter    app-side runtime (no state-management dependency)
packages/jig_getx       GetX adapter, opt-in: HTTP tracing
packages/jig_cli        the `jig` command
packages/jig_mcp        MCP server over stdio, a client of the same verbs
apps/fixture            conformance app; reproduces failure modes on purpose
```

Toolchain: Flutter 3.47.7 / Dart 3.13.5. CI pins the Flutter version deliberately -
see D11 in `openspec/changes/archive/2026-11-13-bootstrap-agent-harness/design.md`.

## Why it exists

Building an end-to-end check for a running Flutter app usually means writing a new
driver script whose first 90% is plumbing - discovering the VM service, walking the
widget tree, guessing positions, retrying - and whose last 10% is the actual check.
The plumbing is what breaks, and it breaks again next week.

Existing harnesses fail on the same two points. They act on coordinates, so a
rebuild between "find" and "tap" makes the position wrong and an overlay can absorb
the tap unnoticed. And they cannot see state held outside the widget tree, as state
management libraries commonly do.

`jig` exists to make the harness a versioned asset instead of a byproduct of each
session.

## Read in this order

1. `README.md`
2. `docs/CONTRACT.md` - the contract is the product
3. `docs/fixture-matrix.md` - how a claim gets verified
4. `openspec/changes/archive/2026-11-13-bootstrap-agent-harness/design.md` -
   decisions D1-D11 and the "M0 results" section
5. `openspec/changes/archive/2026-11-13-add-offscreen-reach/` - why reach and
   element metadata work the way they do
6. `CONTRIBUTING.md` - the non-negotiables

## Where work continues

`openspec/changes/archive/2026-11-13-add-verb-tests-ci-gate` added the test gate, and
`openspec/specs/agent-harness/spec.md` remains the durable contract: ten
requirements, covering what the bootstrap delivered and what reach, back
navigation and element metadata added.

```bash
./tool/verify.sh                          # analysis, every suite, and the wire check
/opsx-propose                             # start the next change
```

`tool/verify.sh` also runs `tool/mcp_smoke.dart`, the only check that spawns the server
instead of calling `JigMcpServer.handle` with a map. It exists because the two failures that
made the server unusable in an editor were invisible to a map-level test: a handshake that
waited on the transport, and a handler exception that ended the process. Both were
reintroduced on purpose to confirm the check goes red.

`ci.yml` runs `analyze` and `test` as separate jobs on the same pinned toolchain;
`tool/verify.sh` is the local equivalent and the two are meant to stay in step.
`packages/jig_getx` has no suite of its own.

`openspec/config.yaml` stops artifacts from padding themselves, and tells `apply` to
batch its checkbox updates and verify once at the end. It is deliberately not a cap
on size: the workflow earns its cost while each artifact says something a reader
could not infer, and it stops earning it when a two-file change grows a design
document with seven decisions. A planned slice may be large; a padded one may not.

## How a change is run now

The orchestrator drives the OpenSpec commands; the human decides priority. Per
change the loop is: propose, apply, archive. The parts that used to cost a session
and no longer do:

- **One verify command.** `./tool/verify.sh`, once, at the end. Not per task.
- **One checkbox pass.** Task boxes are marked together once the behaviour is
  verified, instead of re-reading the instruction payload after every task.
- **The spec is the truth, the change is the delta.** Do not write requirements
  into `openspec/specs/` for behaviour that does not exist yet: the spec would stop
  describing reality, which is what makes a red gate mean something.

The way to run a sequence without re-deciding scope each time is to author the
changes up front, in dependency order, and then apply and archive them one by one.
They all show up in `openspec list`, which is the queue; the CLI does not order
them by dependency, so the order below is the contract.

Writing a widget test here needs one non-obvious thing:
`JigActions._settle` awaits `SchedulerBinding.endOfFrame`, and under `testWidgets`
a frame only happens when the test pumps one, so awaiting a verb future directly
deadlocks. `apps/fixture/test/support/jig_harness.dart` has `drive`, which pumps
while the future runs. Do not solve this by adding a sleep to production code.

A capture needs a second thing on top: `toImage` finishes on the raster thread, and
that callback only arrives through real async, so pumping alone never completes it.
`driveAsync` in the same file interleaves pumps with `runAsync`; use it for
`screenshot` and for anything that decodes an image.

### The queue

Derived from the deferred list and from the fixture rows that are still manual, in
dependency order. The order is a proposal, not a verdict: reprioritise freely.

Done rows are deleted rather than ticked, so this stays a queue and not a log:
`openspec/changes/archive/` is the log.

| # | Change | Why here | Depends on |
|---|---|---|---|
| 1 | `support-ios` | Platform work on the transport, not on the contract | - |

Each row becomes its own change, and all of them can be authored before any is
applied.

## State

| | |
|---|---|
| Verbs | `version`, `launch`, `ping`, `run`, `record`, `export`, `audit`, `tree`, `find`, `tap`, `swipe`, `type`, `clear`, `adjust`, `screenshot`, `wait`, `events`, `state`, `snapshot`, `nav`, `eval`, `back`, `scroll` |
| VM service extensions | 11, which is the stated budget. `clear` rides `type`; pixels needed their own |
| Verified on device | Android 17 / API 37, Flutter 3.47.7: every verb, a scenario, a recording, an exported `integration_test`, `clear` before and after typing, a capture at 1x and 2x, and the MCP server including its `image` result |
| Automated tests | 169 across six packages: `jig_protocol` (protocol round-trips), `jig_driver` (connection), `jig_cli` (session store, argument parsing, the audit report, scenario parsing, the runner, the recorder, the exporter, FVM-aware launch), `jig_mcp` (framing, handshake, tool calls, image results), `jig_flutter` (bus, nav, state, `elements` diagnostics) and `apps/fixture` (23 of the 24 fixture rows plus the icon-font bundle and both edge-to-edge ends, see `docs/fixture-matrix.md`) |
| Deferred | iOS |

## Rules that are load-bearing

- **No coordinate selectors.** Bounds are reported to a caller, never accepted as
  input. A position that a caller supplies is a guess that expires silently.
- **A gesture that cannot be proven to have reached its target is not a success.**
  This is D2, and it was written after a tap on a covered button returned `ok`
  while doing nothing.
- **A pointer path is allowed only with two proofs.** `swipe` emits real pointer
  events because a drag has no semantics action to perform, and that is the one
  place raw coordinates exist. It stays honest by deriving the path from the
  target's own box (the caller names a direction, never a distance or a position),
  hit-testing the origin before emitting anything, and failing
  `GESTURE_NO_EFFECT` when the app does not visibly change. Loosening this is how
  the original thirteen defects came back.
- **Do not fix `BuggyController.confirm()` in the fixture.** It writes the wrong
  step on purpose and is the only end-to-end proof that a failing flow fails.
- **Do not unpin the CI toolchain.** The gate is the product; it must not move by
  itself.
- **`jig_flutter` must not depend on a state management library.** Adopting a test
  harness must not choose an app's architecture. Framework-specific code belongs
  in an optional adapter package.
- **No custom binding, no overlay, no fixed sleep.** Waits are predicates
  evaluated inside the UI isolate.
- **A padding constant is a decision about the system bars.** Android draws the app
  behind them and does not let it opt out, and `ListView(padding: ...)` replaces the
  inset the framework would otherwise apply - so the last row ends inside the
  navigation bar. Derive the bottom value, as `apps/fixture/lib/insets.dart` does.
- **Eleven extensions is the budget.** A new extension needs a reason that outweighs
  the contract cost, because every one of them is something to keep working. Pixels
  bought one; a field clear did not, and rode `type` instead.

## The lesson that cost thirteen defects

Every defect found on a device was the same kind: a command that reported
something other than what happened. None were caught by `dart analyze`.

The worst one returned `{"ok": true}` for a tap on a button covered by a modal,
because the hit test found no handler and the underlying framework call returns
nothing. Silence was indistinguishable from success.

Corollary, now applied to the harness's own diagnostics: any path that returns
"zero results" must say why. The `diag` block on `elements`
(`semanticsEnabled`, `trees`, `nodeCount`, `actionableCount`) turned one such
defect from an afternoon of guessing into a single round trip.

That class of defect is now what `flutter test` is for. `apps/fixture/test` drives
the verbs in-process against the fixture pages and asserts the *failure* cases -
a covered tap, `ELEMENT_NOT_VISIBLE`, `SCROLL_EXHAUSTED`, `ELEMENT_AMBIGUOUS`,
`BACK_REFUSED` - because a verb that lies only lies on the paths where something
went wrong. `docs/fixture-matrix.md` records which rows are covered. Two of them,
20 and 21, are deliberately outside the suite: they need a real pointer path, and
an expected-failure test would turn a known gap into a green tick.

One defect belonged to a class neither the analyzer nor the suite can see: the
fixture app drew every icon as a tofu box for as long as it existed, because its
`pubspec.yaml` had no `flutter:` section and so no Material icon font in the bundle.
The code compiles, the tests pass and the accessibility tree is identical either
way, since an icon-only button has no label regardless of whether it draws a glyph.
What found it was a person reading a `jig screenshot`. Keep the split that implies:
pixels are the only evidence for some claims, and `icons_test.dart` guards the
mechanical half - the asset is in the bundle - so the invisible part cannot return
silently.

## Resolved defect: a keyed wrapper hid its node from discovery

Found while verifying `adjust` on a device, and older than it.

`Slider` carries the caller's `ValueKey` while the semantics node advertising
`increase`/`decrease` belongs to a render object it builds below itself.
`ListView` splits the same way: the key lands on a boundary with no actions while the
scroll actions live on a node covering an identical rectangle. Acting resolved those
correctly, because the acting verbs search the widget tree; the *listing* attributed a key
by walking up from each element's render object, so it either found nothing or found an
ancestor's node. Measured then: `jig find --key rating_slider` returned `count: 0` while
`jig adjust --key rating_slider` worked, on the same frame.

Two rules now decide it, and they are the ones `jig_flutter` keeps:

* a key travels to its own widget's node, and that node may be below the widget - the
  search is over `RenderObjectElement`s in the widget's subtree, never over
  `element.renderObject`, which for a composed widget is already the first descendant;
* when the node a key reaches cannot act but another node covers the identical
  rectangle and can, the key moves to that one. A name that cannot act is not a selector.

`tap` still searches upwards only. That is deliberate and not the same question: listing
asks *which name reaches this node*, acting asks *which node does this name's gesture
belong to*, and a row's key must not become a button inside it.

## Resolved defect: a ref with no owning element

A keyless scrollable emits a ref whose node no element owns - the actioned node is created
by a render object below every element that names it, so `ELEMENT_NOT_FOUND: No widget owns
n178 in the current frame` was the honest answer to a handle the listing had just printed.

A gesture only needs a box, so `swipe --ref` now falls back to matching the node's own
rectangle against painted boxes. `JigRect` is the semantics tree's unit and is in **physical**
pixels; a `RenderBox` reports logical ones, so the comparison scales by `devicePixelRatio`.
Measuring a drag by 80% of the wrong unit would have been a silent off-by-three.

## Measured targets

The fixture predicts failure modes; a real app measures them. A read-only survey of
a large production Flutter app (GetX, 238 files under `lib/presentation`) produced
the numbers that set priorities here:

| Signal | Count | Consequence |
|---|---|---|
| `SingleChildScrollView` | 51 | most content is below the fold |
| `ListView.builder` | 21 | items are not built until scrolled into view |
| `CustomScrollView` (slivers) | 4 | scroll node is not the obvious ancestor |
| scrollable nested in scrollable | 3 | paging the wrong one loses position silently |
| `IconButton` without a label | 76 | `--sem` cannot reach them at all |
| `Key` of any kind | ~8 | the contract's most stable selector is nearly unusable |

Those two last rows are why the element listing carries `key`, `ownerType` and
`rect`, and why `audit` exists as a future step: the gap is application-side
semantics debt, and the harness can only make it visible.

`RefreshIndicator` and `slidable` are documented as failing fixture rows. Both need
a pointer-path gesture, which is out of scope by design. Leaving them red documents
the gap; making them pass with a synthetic drag would reintroduce the design that
produced the thirteen defects.

## Environment note

The shell a session starts in may not be this repository. Use absolute paths, or
confirm `pwd` before relative ones.
