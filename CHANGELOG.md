## 0.1.0-dev.1

Pre-alpha. The wire contract, the app-side runtime, the GetX adapters, the driver
and the CLI exist and have been exercised on a device against the fixture;
`jig_mcp` and the scenario surface are not written yet.

- `jig_protocol`: selectors, elements, events, responses and error codes.
- `jig_flutter`: event bus, semantics-driven element index, diagnostic
  extensions and the log/error taps.
- `jig_getx`: `JigConnect` HTTP tracing. Navigation needs no adapter:
  `Jig.navigatorObserver` is a plain `NavigatorObserver`.
- `jig_driver` / `jig_cli`: VM service transport and the `jig` command.
- `apps/fixture`: GetX conformance app that reproduces the failure modes of
  existing harnesses.
