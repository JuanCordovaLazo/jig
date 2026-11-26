## 1. Spike (M0) - go/no-go before anything else

- [x] 1.1 Install on the fixture and confirm `ext.jig.ping` answers over the VM service
- [x] 1.2 Confirm `vm.evaluate` resolves `Get.find<ApiController>().lastStatus.value`
      (verified with `CartController.count`; both are plain `Rx.value` reads)
- [x] 1.3 Confirm a semantics `tap` works while a `Get.snackbar` and a `Get.dialog` are open
- [x] 1.4 Confirm `postEvent` reaches `onExtensionEvent` with `jig.<source>`
- [x] 1.5 Confirm `flutter run --machine` yields `app.debugPort` with a usable `wsUri`
- [x] 1.6 Record the outcome in `design.md` ("M0 results"); six defects found and fixed

## 1b. Finish M0 on a device

- [x] 1b.1 Re-run the covered-target case: `tap --key overlay_target` with a dialog
      open must fail `ELEMENT_NOT_VISIBLE`, never return `ok`
- [x] 1b.2 Verify `jig events --since <seq>` returns the events a `tap` caused
- [x] 1b.3 Verify `jig type --sem '<label>' --value '...'` on the form screen
- [x] 1b.4 Verify `jig wait --sem '<label>' --absent` after closing a dialog
- [x] 1b.5 Run the whole `docs/fixture-matrix.md` once and tick row 11 fails as expected

## 2. Contract and transport (M1)

- [x] 2.1 `jig_protocol`: envelope, ten error codes with wire strings, four selector kinds
- [x] 2.2 `jig_driver`: attach, isolate discovery, extension call, typed failures
- [x] 2.3 `jig_driver`: `evaluate` and `waitForExpression` with documented limits
- [x] 2.4 `jig_cli`: `version`, `ping`, `tree`, `find`, `tap`, `type`, `wait`, `state`, `snapshot`, `events`, `nav`, `eval`
- [x] 2.5 `jig_cli launch` publishes `.jig/session.json`, stays foreground, cleans up on exit
- [x] 2.6 Single JSON envelope on stdout, exit codes 0/1/2

## 3. App-side runtime (M1)

- [x] 3.1 `JigBus`: bounded ring, monotonic seq, source filter, `postEvent` mirror
- [x] 3.2 `JigElementIndex`: semantics traversal, action mapping, refs
- [x] 3.3 `JigActions`: tap by label, tap through the nearest live semantics node (no coordinate
      path - see D2), `tapRef`, `typeText`
- [x] 3.4 `JigStateRegistry`: named readers, per-entry error isolation
- [x] 3.5 `JigNavHistory` + `JigNavigatorObserver`
- [x] 3.6 `Jig.install()`: semantics handle, chained error handler, idempotent
- [x] 3.7 `JigExtensions`: the eight extensions, no handler leaking a stack trace

## 4. GetX adapters (M2)

- [x] 4.1 `JigConnect` overrides the six request methods, traces success and failure
- [x] 4.2 `Jig.logWriter` usable as `logWriterCallback`, forwarding to the previous writer
- [x] 4.3 Document that navigation needs no adapter

## 5. Fixture (M1-M2)

- [x] 5.1 Eleven screens/cases per `docs/fixture-matrix.md`
- [x] 5.2 In-app `HttpServer` on loopback: 200, 401-then-200, timeout
- [x] 5.3 `BuggyController` writes the wrong step on purpose; documented as load-bearing
- [x] 5.4 Android platform folder; `flutter build apk --debug` succeeds

## 6. Verification

- [x] 6.1 `dart analyze .` clean across the workspace
- [x] 6.2 Every row of the fixture matrix executed at least once on Android
- [x] 6.3 A failing flow (row 11) demonstrably times out rather than passing
- [x] 6.4 No command mutates app state except through `tap`/`type`

## 7. Publishing

- [x] 7.1 `README.md` documents adoption in four lines plus git-ref pinning
- [x] 7.2 `docs/CONTRACT.md` states the stability policy
- [x] 7.3 CI: `dart pub get`, `dart analyze .`, `flutter analyze` in the fixture
- [x] 7.4 `NOTICE` identifies the copyright holder; `CONTRIBUTING.md` states the
      contribution licensing terms and the non-negotiables
- [x] 7.5 Tag `v0.1.0-dev.1`

## 8. Deferred (own change)

- [ ] 8.1 `jig_mcp` over stdio
- [ ] 8.2 `run scenario.yaml`, `record`, `audit`
- [ ] 8.3 Gestures: long press variants, drag, swipe, `key`
- [ ] 8.4 iOS via `simctl`
- [ ] 8.5 Export a recorded flow to `integration_test`
