# Fixture matrix

`apps/fixture` is not a demo. Each screen reproduces one specific way an
end-to-end harness lies, so a parity claim about `jig` can be checked instead of
asserted.

Run any row with the app on a device and `jig` attached. Rows marked in the last
column are also asserted by `flutter test` without a device, in
`apps/fixture/test`; the device run is still the reference for timing and
rendering.

| # | Failure mode | Screen | Command that proves it | In the suite |
|---|---|---|---|---|
| 1 | Overlay owns the pixels; the target's old position still "works" | `/overlays` | `jig tap --key overlay_target` then `--key overlay_target` again | `tap_contract_test.dart` |
| 2 | Position computed before a rebuild is already wrong | `/live-list` | tap `toggle_shuffle`, then `jig tap --key row_3` | `live_list_test.dart` |
| 3 | Modal barrier vs. bottom sheet | `/overlays` | `jig tap --key show_sheet`, then `jig tap --key sheet_close` | `tap_contract_test.dart` |
| 4 | Widget tree is not the accessibility tree | `/opaque` | `jig tree` lists `Objetivo etiquetado` and never the unlabelled tappable; `jig tap --key opaque_target` fails `ELEMENT_NOT_VISIBLE` | `tap_contract_test.dart` |
| 5 | State is invisible in the widget tree | anywhere | `jig snapshot` returns `cart.count`, `route`, ... | `state_events_test.dart` |
| 6 | Transport failures never reach a response modifier | `/` via `api.last` | `jig eval` or a button calling `loadSlow()`, then `jig events --sources http` shows the `error` | `http_events_test.dart` |
| 7 | 401 retried by the authenticator, then succeeding | `/` | `loadSecure()`, then `jig events --sources http` shows a `200`; the `401` never leaves the call, because the authenticator retries inside it | `http_events_test.dart` |
| 8 | Log volume drowns the signal | any | `jig events --since <seq> --sources log --limit 20` | `state_events_test.dart` |
| 9 | Most rows are not rendered | `/scroll` | `jig tap --key item_450` fails `ELEMENT_NOT_FOUND` with the rendered rows as candidates; `jig scroll --key item_450` returns a ref and `jig tap --ref <ref>` acts on that row | `scroll_contract_test.dart` |
| 10 | Text entry is not a tap | `/form` | `jig type --sem 'Nombre' --value 'Ana'`, then `jig tap --key submit` | `form_test.dart` |
| 11 | A flow that must go red | `/buggy` | tap `buggy_step_one`, `buggy_step_two`, then `jig wait --state 'Get.find<BuggyController>().step.value == 2' --timeout 3` times out while `jig snapshot --names buggy.step` still reads `1` | manual, on purpose |
| 12 | The scroll node is a viewport, not the obvious ancestor | `/sliver` | `jig tap --key sliver_55` fails `ELEMENT_NOT_FOUND`; `jig scroll --key sliver_55` returns a ref whose `tap --ref` reports `Sliver 55` | `scroll_contract_test.dart` |
| 13 | A scrollable inside another scrollable | `/nested-scroll` | `jig scroll --key inner_39` fails `ELEMENT_AMBIGUOUS` with `inner_list` among the candidates; `jig scroll --key inner_39 --in inner_list` returns a ref | `scroll_contract_test.dart` |
| 14 | Paging on the other axis | `/tabs` | `jig scroll --key second_tab_target --axis horizontal` returns a ref; the same command without `--axis` fails `ELEMENT_NOT_VISIBLE` | `scroll_contract_test.dart` |
| 15 | Back must obey the app, not the harness | `/back-gate` | the first `jig back` fails `BACK_REFUSED`; after `jig tap --key confirm_leave`, `jig back` pops to `/` | `back_contract_test.dart` |
| 16 | Modals stack, and a result has to land somewhere | `/stacked-dialogs` | `jig tap --key open_dialog`, `jig tap --key dialog_open_sheet`, then `jig back` twice: each removes one modal and the route survives; `jig tap --key dialog_confirm` leaves `jig snapshot --names dialog.result` reading `confirmed` | `stacked_dialogs_test.dart` |
| 17 | An icon-only control has no name at all | `/` | `jig tree` lists an `IconButton` with an empty label; `jig tap --type IconButton --index 1` still works | `home_test.dart` |
| 18 | A covered target must not be paged into view | `/scroll` | `jig tap --key scroll_open_dialog`, then `jig scroll --key item_450` fails `ELEMENT_NOT_VISIBLE` and the rendered rows are unchanged | `scroll_contract_test.dart` |
| 19 | A budget is not the same as the end of the content | `/scroll` | `jig scroll --key item_99999 --steps 30` fails `SCROLL_EXHAUSTED` naming the budget; past the end the message says the content ended | `scroll_contract_test.dart` |
| 20 | Pull to refresh needs a drag | `/refresh` | `jig swipe --key refresh_list --direction down`, then `jig snapshot --names refresh.count` reads `1` | `refresh_contract_test.dart` |
| 21 | Swipe actions need a drag | `/slidable` | `jig swipe --key slidable_row --direction left`, then `jig tree` lists a `Delete` action that was not there before | `swipe_contract_test.dart` |
| 22 | Emptied is not the same as cleared | `/form` | `jig type --sem 'Nombre' --value 'Ana'`, then `jig clear --sem 'Nombre'`, then `jig find --sem 'Nombre'` reports an empty value | `form_test.dart` |
| 23 | A capture is not the accessibility tree | `/form` | `jig screenshot` writes a PNG of the page that shows what `jig tree` cannot name | `screenshot_contract_test.dart` |
| 24 | A range control has no tap action | `/form` | `jig adjust --key rating_slider --times 2` returns `value: "100%"`; the same call again fails `ADJUST_REFUSED` naming the maximum | `adjust_contract_test.dart` |

Row 11 is manual on purpose: it is the only end-to-end proof that a failing flow
fails, and automating it would make it pass. Every other row is asserted in-process.

Two notes for whoever adds a test here. Rows 6 and 7 use a plain `test` rather than
`testWidgets`, because the widget binding answers every HTTP request with a 400 and
never opens a connection. Row 21 asserts presence in the tree rather than a
`--key` selector: the key sits on the `SlidableAction` wrapper while the semantics
node belongs to the `OutlinedButton` inside it, so the label is the handle that
works.

Row 20 is the one place a fixture change was needed: `RefreshIndicator` fires a
callback and records nothing, so `RefreshController` counts refreshes and
`refresh.count` makes them observable. The test asserts that number, not the absence
of an exception.

The drag has to be on the list, not on a row: 80% of a 56 px row is far short of the
indicator's threshold, so `swipe --key refresh_row_0 --direction down` dispatches and
correctly reports `GESTURE_NO_EFFECT`. Verified on a 2560x1440 tablet -
`refresh.count` goes `0` to `1` with `--key refresh_list`, and the ref path works too
because the node carries the key.

Row 23 needs `driveAsync` rather than `drive`: `toImage` completes on the raster
thread, and that callback is only delivered through real async, so pumping frames on
their own never resolves the future. Row 22's refusal branch is asserted in-process
against a field whose formatter always re-adds a prefix, because a field that refuses
to empty is the only way to reach `CLEAR_REFUSED`.

Row 23 is also how a real defect surfaced: the fixture drew eleven `Icons.*` as tofu
boxes, because `pubspec.yaml` had no `flutter:` section and so no Material icon font in
the bundle. Nothing else saw it - the analyzer is clean, every widget test passes, and a
labelled-by-nobody `IconButton` reads identically with or without a glyph. The capture is
what made it visible; `apps/fixture/test/icons_test.dart` now asserts the font is in the
bundle so the mechanical half cannot come back silently.

## Edge to edge

The fixture targets SDK 36 and runs on API 37, where Android draws the app behind the
system bars and does not let it opt out. The geometry this was measured on, from
`dumpsys window`'s `InsetsSource` frames on a 1080x2400 screen at 420dpi:

| Band | Pixels | Logical |
|---|---|---|
| status bar | `0..63` | 24dp |
| navigation bar | `2274..2400` | 48dp |

Three surfaces put content inside the navigation bar, all for the same reason: a padding
constant replaces the inset a scroll view derives from `MediaQuery`. Home's last row and
the overlays page's bottom button both ended at `2358` (84px inside the bar), and the
bottom sheet's button at `2337` (63px inside). `lib/insets.dart` derives the bottom value
instead, and the same three end at `2232`, `2232` and `2211`.

What was already correct, and is worth knowing before changing it:

- the long list, which never wrote a padding, stops at exactly `2274` - the framework's own
  inset;
- the FAB is placed above `Scaffold`'s `minInsets`;
- with the keyboard up, the body resizes and the form's content ends far above the IME;
- the GetX snackbar wraps itself in `SafeArea(top: true)`, so its text sits below the
  status bar; its rounded background still grazes it by about 18px, which is the library's
  layout and not the fixture's to override.

`apps/fixture/test/edge_to_edge_test.dart` asserts the two ends that a screenshot cannot:
the first row below the status bar and the last row above the navigation bar at full
scroll, on a simulated 1080x2400 view.

## Why row 11 exists

Without it, the harness's success criterion degrades to "the command did not
throw". `BuggyController.confirm()` writes step `1` on purpose. A scenario that
asserts `buggy.step == 2` must time out; if it passes, either the wait is not
being evaluated or the state reader is lying.

Keep this bug. Fixing it removes the only end-to-end proof that failures are
detected.

## Adding a row

1. Reproduce the failure mode on a new screen, not by editing an existing one.
2. Give every interactive widget a `ValueKey` **and** a readable label.
3. Register whatever the agent must assert on with `Jig.state(...)`.
4. Add the row here, with the command that proves it.
