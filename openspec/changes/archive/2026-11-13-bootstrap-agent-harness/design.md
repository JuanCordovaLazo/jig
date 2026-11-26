## Context

`jig` is developed against a fixture app, never against a real product app.
Building it against a 14-hour-compiling app with Firebase, `.env` and brands
would make the harness inherit exactly the problems it is meant to remove.

The fixture must therefore reproduce the failure modes, not just look plausible.
It is the regression suite for the harness itself.

## Goals / Non-Goals

**Goals**

- Act on elements without coordinates supplied by the caller.
- Read GetX state without instrumenting call sites or repositories by hand.
- Fail loudly and usefully: every failure carries candidates and a next command.
- Keep `jig_flutter` free of state-management dependencies.
- Keep the surface small: eight extensions, twelve CLI verbs.

**Non-Goals**

- Production runtime, release-mode support, or RUM.
- Web or desktop drivers.
- A visual test recorder.
- Replacing `integration_test`/Patrol for CI regression; `jig` is for
  investigation and pre-CI authoring, and may export to `integration_test` later.

## Decisions

### D1 - Act through the semantics tree, not the widget tree

`SemanticsOwner.performAction(id, action)` is the framework's own path for
accessibility actions. It is computed per frame, unaffected by whatever a router
inserts above the route, and it reflects what is actually reachable.

Consequence: an element hidden behind a modal is *not findable*, and the command
fails with `ELEMENT_NOT_FOUND`. That is the desired behaviour and the reason a
coordinate is never a selector.

Cost: `SemanticsBinding.ensureSemantics()` must be held for the session. It is
released on `Jig.uninstall()`.

Alternative rejected: synthetic pointer events (`GestureBinding.handlePointerEvent`)
reproduce the coordinate problem and cannot distinguish "the tap landed on the
right widget" from "the tap landed" - this is the design that produced the
"invoke the callback directly when hit-testing fails" escape hatch in
`flutter_skill`.

### D2 - There is no coordinate path at all

Originally this decision allowed a fallback: when a selector matched a widget
rather than a semantics node, the widget's centre was computed from its render box
and passed to `SemanticsOwner.performActionAt`.

M0 killed that fallback. Tapping a button that was covered by a `Get.dialog`
returned `{"ok": true}` and did nothing: the render box existed and had a valid
centre, the semantics hit-test found no handler, and `performActionAt` returns
`void` - so the silence was indistinguishable from success.

The resolution is stricter, not softer: every tap resolves to a semantics node
that advertises the action, obtained by walking up from the matched widget to the
nearest ancestor with `debugSemantics` carrying that action. If no such node
exists, the command fails with `ELEMENT_NOT_VISIBLE` and explains that the target
is probably behind a modal. A gesture that cannot be proven to have reached its
target is not reported as a success.

Consequence: a widget with no semantics is not tappable. That is correct, and
`audit` (M3) is how the gap gets surfaced and fixed in the app rather than
papered over in the harness.

### D3 - State via named readers first, `vm.evaluate` second

`vm.evaluate` answers ad-hoc questions against `Get.find<T>()` without touching
the app, but it needs a library scope, is debug-only, and fails on some generic
instantiations. Named readers (`Jig.state('cart.total', () => ...)`) have none of
those problems and collapse a snapshot into one extension call.

`evaluate` remains available as `jig eval`, and its failure mode is documented as
"register a reader", not "the app is broken".

### D4 - HTTP tracing lives in overrides, not modifiers

`GetConnect` converts transport failures into `GetHttpException` without invoking
any response modifier, so a modifier-only design reports successes and silently
drops timeouts. `JigConnect` overrides `get/post/put/patch/delete/request`, which
means one change - `extends GetConnect` becomes `extends JigConnect` - instruments
every repository beneath a base class.

Rejected: request/response modifiers alone (blind to failures).

### D5 - `jig_flutter` has no GetX dependency

`LogWriterCallback` is `void Function(String text, {bool isError})`. Dart function
types are structural, so `jig_flutter` declares that shape and
`GetMaterialApp(logWriterCallback: Jig.logWriter)` compiles without the package
knowing GetX exists. GetX-specific code lives in the optional `jig_getx`.

### D6 - Waits are predicates inside the UI isolate

`ext.jig.wait` polls with a `Timer` in the same isolate that produces frames, so
there is no round trip between the check and the frame that would satisfy it. The
driver polls `evaluate` only for predicates that have no widget to hang off, and
that path is documented as slower.

### D7 - Event bus with a monotonic sequence

Events are stored in a bounded ring (4,096) and mirrored through
`developer.postEvent`. The buffer is authoritative; the mirror is best effort.
Every response carries `seq`, so `tap` then `events --since <seq>` shows exactly
what the action caused - and the buffer bound stops the diagnostic from becoming
the leak.

### D8 - Error handler is chained, not replaced

`Jig.install()` wraps `FlutterError.onError`, captures, then calls the previous
handler. A crash reporter registered before `runApp` keeps working.

### D9 - Pub workspace, not melos

Dart 3.9+ resolves the six members from one lockfile and one `pub get`. No extra
tooling, no extra lockfiles.

### D10 - Failures are typed and actionable

Ten error codes, each with a defined caller response. `candidates` and `hint` are
part of the contract because the alternative - an agent retrying blindly - is the
behaviour this project exists to remove.

### D11 - The CI toolchain is pinned, not floating

CI pins Flutter `3.47.7` instead of tracking `stable`. The first CI run proved why:
on Flutter 3.50 `package:flutter/material.dart` is deprecated in favour of
`package:material_ui/material_ui.dart`, so an ordinary runner image update turned
the analyze gate red for a reason that says nothing about this code.

A repository whose value is that a red build means something cannot let its
verification environment drift underneath it. Bumping the version is a deliberate
commit that carries its own migration, and the workflow records the reasoning so
the next person does not "fix" it by unpinning.

## Risks / Trade-offs

- **Semantics coverage.** Widgets without labels are invisible. Mitigation: the
  fixture ships an unlabelled control next to a labelled one, and `audit` (M3)
  will enumerate the gap. The fix belongs in the app.
- **`evaluate` fragility.** Generic instantiations can fail to compile. Mitigated
  by making readers the primary path and documenting the failure as "register a
  reader".
- **SDK pin drift.** Consensus with consumer apps is required; the fixture pins
  `get: 4.7.3` exactly and each app resolves its own Flutter version.
- **Bound sessions.** A crashed `jig launch` can leave a stale `.jig/session.json`.
  Mitigated by writing the file only once the VM service URI exists and deleting it
  on exit.
- **Scope creep toward a framework.** The eight-extension budget is the guard.

## Migration Plan

1. Land the repository with the fixture green.
2. Adopt in one app as a separate change: `Jig.install()`,
   `logWriterCallback`, navigator observer, `extends JigConnect`.
3. Adopt in a second app before claiming reuse.
4. Retire the previous harness only when five real flows pass and no driver script
   remains in the app repository.

## Open Questions

- ~~Does `developer.postEvent` survive on 3.44 through 3.47 identically?~~ Answered
  on 3.47.7: yes, verified against a live `Extension` stream listener. Re-check
  when the pinned toolchain moves.
- Does every repository in the adopting app funnel through one base class, or does one
  construct its own `GetConnect`? Adoption step will confirm.

## M0 results

Run on `emulator-5554` (Android 17 / API 37, x86_64), Flutter 3.47.7, GetX 4.7.3.

Confirmed:

- `ext.jig.ping` answers over the VM service and reports the registered readers.
- `vm.evaluate` resolves GetX state: `Get.find<CartController>().count.value` →
  `{"ok":true,"value":"0","kind":"Int"}`. D3 holds.
- With a `Get.snackbar` and a `Get.dialog` open, the semantics tree drops from 22
  nodes to 3 and the covered controls leave it entirely. D1 holds, and the modal
  case is visible rather than inferred.
- `flutter run --machine` yields `app.debugPort` with a usable `wsUri`, and the
  session file round-trips between processes.
- `developer.postEvent` reaches a VM service `Extension` stream listener with the
  bus payload intact: a single `tap` produced `jig.log`, `jig.nav` and
  `jig.custom`, all carrying the same `seq`/`source`/`data` the buffer holds. The
  mirror is a usable subscription path, not just a debug-console message.

Six defects were found and fixed, none of which unit tests would have caught
before the harness had ever driven a device:

1. **Session was unreachable.** `discover()` looked for `<dir>/session.json` while
   `launch` published `<dir>/.jig/session.json`, so every command but `launch`
   reported `NOT_CONNECTED` with a live app running.
2. **The element index was always empty.** `rootPipelineOwner.semanticsOwner`
   exists but has no root node; the tree belongs to each `RenderView`'s pipeline
   owner. `tree` returned `count: 0` on a screen with six buttons.
3. **`--sem` did not exist.** The parser only knew `--semantic`, so every command
   as documented in the README exited 2 with a usage dump.
4. **Silent success.** Covered-target taps returned `ok` without acting. See D2.
5. **`elapsedMs` was always 0**, contradicting the contract on every response.
6. **A covered tap could not be told apart from a miss**, because the failure had
   no typed error - fixed by removing the coordinate path.

Lesson worth keeping: the diagnostics block on `elements` (`semanticsEnabled`,
`trees`, `nodeCount`, `actionableCount`) is what turned defect 2 from an
afternoon of guessing into one round trip. Any future "0 results" path should
report why, for the same reason.

## Found while finishing M0 (task 1b)

Driving every row of `docs/fixture-matrix.md` found seven more, again all of the
same kind - a command that reports something other than what happened:

7. **`wait` said present for a covered widget.** Presence for `--key`/`--type`
   checked the element tree and `RenderObject.debugSemantics` kept the last node
   it had computed, so a widget behind a sheet waited green and then failed to
   tap. Presence now means "a node in the *current* tree advertises the action",
   the same test `tap` applies.
8. **`jig type` never worked on a normal `TextField`.** Flutter only advertises
   `SemanticsAction.setText` while the field has focus, so the label node had
   `focus` but no `setText` and the command fell through to the editable-text
   path, which could not find the field either. `type` now focuses first and
   waits one frame for the action to appear; the form row proves the value lands.
9. **`waitedMs` reported the budget.** `wait` echoed the timeout it was given, so
   an immediate match and a full timeout were indistinguishable. It now reports
   the wait that actually happened.
10. **`jig wait --state` was documented and absent.** The README used it; the
   parser rejected it. It now polls `JigConnection.waitForExpression`, and the
   envelope still carries `seq` so a failed wait can be chained into `events`.
11. **A timed-out request was traced as a success-shaped response.**
   `GetConnect` returns a bodiless `Response` with a null status for some
   transport failures, and `JigConnect` logged it as `response`. It is now an
   `http` `error` event with the elapsed time, which is what the spec asks for.
12. **The live-list screen threw instead of rendering.** `isShuffling` was a
   plain getter read inside an `Obx`, so GetX raised "improper use of a GetX" and
   the page had no actionable nodes. The flag is an `RxBool` now, and reading the
   getter subscribes.
13. **The opaque fixture was not opaque.** The unlabelled tappable inherited a
   label from its child `Text`, so row 4 passed for the wrong reason.
   `excludeFromSemantics` plus `ExcludeSemantics` make it genuinely invisible -
   and `tap` on it now fails `ELEMENT_NOT_VISIBLE`, which is the row's point.
