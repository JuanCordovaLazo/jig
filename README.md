# jig

An agent-driven test rig for Flutter.

> A *jig* is the fixture that holds a workpiece and guides a tool so the same
> operation comes out identical every time. It does not test the part - it holds
> it so the work is repeatable. That is what an end-to-end harness is.

`jig` lets an agent launch your app, see what is actionable inside it, act on it,
and read what happened - HTTP, logs, navigation and registered state - without a
screenshot in the loop and without a script per question.

```
jig launch --device emulator-5554
jig tap --sem 'Agregar al carrito'
jig snapshot
jig events --since 128 --sources http,nav,errors
jig wait --state 'Get.currentRoute == "/checkout"' --timeout 5s
```

## Status

1.0. The whole vertical slice runs: the contract, the app-side runtime, the
GetX adapters, the driver, the CLI, the scenario runner and the MCP server. Twenty-three
CLI verbs over eleven VM service extensions.

| Milestone | State |
|---|---|
| M0 - spike (`evaluate`, semantics tap, `postEvent`, `launch`) | verified on a device: Android 17 (API 37), Flutter 3.47.7 |
| M1 - Android vertical slice | done: semantics-driven acting, reach beyond the viewport, back navigation |
| M2 - observability (`JigConnect`, log tap, nav) + MCP server | done: `jig_mcp` speaks MCP over stdio |
| M3 - scenarios (`run`, `record`, `export`) and `audit` | done: scenarios replay, record and export; `audit` reports accessibility debt |

Swipe is the one verb that emits a pointer path, because a drag has no semantics
action to perform. It was added deliberately, and the rule it had to satisfy is
written down under **Rules that are load-bearing**: the path is derived from the
target's own box, a named direction is the only input, the origin is hit-tested
before anything is emitted, and a gesture that changes nothing fails
`GESTURE_NO_EFFECT` rather than reporting `ok`.

Every fixture row except row 11 - which is red on purpose, as the only end-to-end proof
that a failing flow fails - is asserted in-process.

The whole surface has also been run against a real device (Android 17 / API 37, Flutter
3.47.7): every verb, a scenario, a recording, an exported `integration_test` and the MCP
server. That is where the last five defects came from - a fake that encoded the wrong
wire shape passes happily while the app returns something else.

Still out of reach: iOS. See the queue in [docs/HANDOFF.md](docs/HANDOFF.md).

The toolchain is pinned to Flutter `3.47.7` in CI. Bumping it is a deliberate
commit, not a side effect of a runner image update - the gate is the product, so
it must not move by itself. Local development on a newer stable is fine; see
[.github/workflows/ci.yml](.github/workflows/ci.yml) for the reason it is pinned.

## Packages

| Package | Runs in | Carries |
|---|---|---|
| `jig_protocol` | anywhere | the wire contract: selectors, elements, events, errors |
| `jig_driver` | your machine | VM service transport and verbs |
| `jig_flutter` | the app | bus, semantics index, actions, extensions |
| `jig_getx` | the app | `JigConnect` HTTP tracing for GetX |
| `jig_cli` | your machine | `jig` |
| `jig_mcp` | your machine | MCP server over stdio, so an agent can call the same verbs |
| `apps/fixture` | a device | GetX app that reproduces the hard cases on purpose |

`jig_flutter` has no dependency on `get`, `bloc` or `provider`: adopting a test
harness must not choose an architecture. GetX-specific code lives in `jig_getx`,
which is opt-in.

### MCP

`jig_mcp` serves the same verbs to an agent runtime over stdio, so an editor can drive
an app without a shell:

```bash
dart run jig_mcp:jig_mcp --uri ws://127.0.0.1:<port>/ws
```

It is another client of the eleven extensions, not a new surface. Fourteen tools, named
like the verbs they drive, plus `connect`. The verbs that belong to a shell are not tools: `launch` owns a
foreground process, `run`/`record`/`export` read and write files, `eval` is an escape
hatch, and `find`/`snapshot`/`version` are conveniences of the CLI.

The tool list is the whole manual a model gets - it never reads this file - so each
description carries what the verb does, which arguments are mandatory, what comes back,
and the error a caller should expect (`ELEMENT_NOT_VISIBLE`, `GESTURE_NO_EFFECT`,
`CLEAR_REFUSED`, and the rest). `packages/jig_mcp/test/tools_contract_test.dart` fails the
build when a tool or an argument loses its description, when a selector verb stops
declaring that one spelling is required, or when a closed set of values stops being an
enum.

The `initialize` reply also carries `instructions`, which is the one place a server can say
how its tools relate to each other rather than describing thirteen equally. It ranks them
by cost - `state`/`events`/`nav`, then `tree`, then the acting verbs, then `screenshot` -
and says what `screenshot` is not for: it cannot be asserted on, it says nothing about what
is actionable, and it is the wrong tool for locating an element. A tool description can
explain one verb; only `instructions` can tell a model that a cheaper verb already holds
the answer.

An app-side failure comes back as a tool result with `isError: true` carrying the jig error
JSON, never as successful text, and a request with unusable arguments is a JSON-RPC
`invalid params` instead - the tool did not run, so it cannot have failed. With no session
it still starts and reports `NOT_CONNECTED` per call, because a subprocess that exits
cannot tell a client why.

The target is chosen the way the CLI chooses it: `--uri`, then `$JIG_URI`, then the nearest
`.jig/session.json` walking up from the working directory. The environment variable matters
more here than in a shell, because a portable MCP configuration cannot prompt for a value.

The `connect` tool changes the target at runtime: give it the `ws://` URI `jig launch`
printed and the rest of the tools use it, which is how a client that cannot choose the
server's working directory still reaches an app.

Connecting is *deferred*: `initialize` and `tools/list` answer before any socket is opened,
and the connection is made on the first tool call. That ordering is not an optimisation. A
stale session file pointing at a host that never answers used to hold the handshake for 134
seconds, so every client gave up and reported a server that never became ready - a report
that says nothing about the real cause.

`screenshot` is the one tool whose answer is not text: it returns an `image` content
block with the PNG plus a text block carrying the dimensions, so a model can look at the
app instead of inferring it from the accessibility tree.

#### In VS Code

Nothing to install: the server is a `dart run` of the package in this workspace. You add
it as an MCP server in your editor.

Use `.mcp.json` at the root of the **workspace you open**, in the portable `mcpServers`
format:

```json
{
  "mcpServers": {
    "jig": {
      "type": "stdio",
      "command": "dart",
      "args": ["run", "jig_mcp:jig_mcp"],
      "tools": ["*"]
    }
  }
}
```

`.vscode/mcp.json` is the older, editor-managed format (top-level `servers`); VS Code
marks it as deprecated and the Copilot harness does not read it directly, which is why
this project moved to `.mcp.json`. Three consequences of the portable format matter here:

- **No `inputs`.** `inputs` and `${input:...}` are editor-only fields; copying them into
  `.mcp.json` does nothing. A value that changes on every launch travels as an
  environment variable instead - and `jig` already reads `JIG_URI` in both entry points.
- **No prompt.** So the server must find the app on its own, or be handed the URI through
  the environment.
- **`tools: ["*"]`** makes every tool available; it does not auto-approve calls, so each
  one is still yours to allow.

Two shapes, depending on how the server should find the app:

- **Project scoped, nothing to fill in.** `apps/fixture/.mcp.json` is committed and says
  exactly the snippet above. Open `apps/fixture` as the workspace and start `jig`: the
  server reads `.jig/session.json` from that folder, which is what `jig launch` writes.
- **Your own app.** Same file, plus a URI when discovery cannot see one.

1. Launch the app and leave it running. `jig launch` prints the VM service URI and writes
   it to `apps/fixture/.jig/session.json`:

   ```bash
   cd apps/fixture && dart run jig_cli:jig launch -d emulator-5554
   ```

2. Add the server. Either run **MCP: Add Server** -> *Command (stdio)* with
   `dart run jig_mcp:jig_mcp`, or write `.mcp.json` yourself. Discovery walks *up* from the
   server's working directory and never down, so a server started at the repo root cannot
   see `apps/fixture/.jig/session.json` - that is the case where the URI has to be passed:

   ```json
   {
     "mcpServers": {
       "jig": {
         "type": "stdio",
         "command": "dart",
         "args": ["run", "jig_mcp:jig_mcp", "--uri", "${JIG_URI}"],
         "tools": ["*"]
       }
     }
   }
   ```

   `${JIG_URI}` is an environment reference, substituted from the environment of whatever
   host runs the server. Export it before starting the editor, or set `JIG_URI` in the
   server entry's `env`. Passing `--uri "${JIG_URI}"` with the variable unset hands the
   server the literal text, so export it first - `echo $JIG_URI` is the check.

   One more option, unverified: `cwd` is a documented field of the format but absent from
   VS Code's configuration form, so it can only be set by editing the file. If it is
   honoured, `"cwd": "apps/fixture"` would let discovery work from the repo root. Treat it
   as something to try rather than something this project has measured - the measured path
   is opening `apps/fixture` as the workspace.

3. Start the server: **MCP: List Servers**, or the server controls in the session. The
   guided destination for a workspace-root `.mcp.json` is behind the experimental
   `chat.mcp.workspaceRootConfig.enabled` setting; a file you wrote by hand is picked up
   either way.

4. In Copilot Chat, enable the tools for the agent session. They appear with the verb
   names: `connect`, `ping`, `tree`, `tap`, `swipe`, `type`, `clear`, `adjust`, `screenshot`,
   `wait`, `scroll`, `state`, `events`, `nav`, `back`.

**If the tools do not appear**, the server is the first thing to rule out, and the log says
which of the two it is. In the editor's `agenthost.log`:

- `MCP server 'jig' connected (ready)` - the host has the tools; look at the session's tool
  selection instead.
- `MCP server 'jig' connected (starting)` - the handshake did not complete. Run
  `dart run tool/mcp_smoke.dart` from the repository root: it spawns the server and speaks
  the protocol to it, so a green run moves the problem into the host's configuration, and a
  red one names the broken step.

A hard-coded port goes stale silently, and a server pointed at a dead URI answers every
tool with `NOT_CONNECTED` rather than failing loudly at start, which is why the environment
variable is the recommended path rather than a convenience.

The session file only exists for an app `jig launch` started. If you ran plain
`flutter run`, there is nothing to discover: export `JIG_URI` from the `ws://...` line
`flutter run` prints.

If the app uses FVM, `dart` on your PATH is not necessarily the SDK the project pins.
`jig launch` resolves that itself - it runs `fvm flutter run --machine` when the project,
or any directory above it, is pinned - but the editor spawns the MCP server, so name the
interpreter there:

```json
{
  "mcpServers": {
    "jig": {
      "type": "stdio",
      "command": "fvm",
      "args": ["dart", "run", "jig_mcp:jig_mcp"],
      "tools": ["*"]
    }
  }
}
```

Two things that bite here. The server has to start **inside a pinned project**: `fvm` with
no pin and no global version exits `0` without running anything, so the client reports a
server that dies on start instead of a missing pin. `fvm dart --version` is the check -
it prints the pinned version when there is one, and prints nothing when there is not. And
if `fvm` is not on the editor's `PATH` (a GUI launch, a sandbox), point at the SDK the pin
already created instead: `"command": "${workspaceFolder}/.fvm/flutter_sdk/bin/dart"`.

**Limits worth knowing.** There is no authentication and no sandbox: an MCP client that
can call `tap` can drive the app exactly as a developer could. Run it against debug
builds of apps you already trust, and do not expose the VM service port beyond
loopback. Tool results are JSON text blocks, except `screenshot`, which returns an
`image` block plus the dimensions as text.

## Try it

```bash
dart pub get
cd apps/fixture
flutter run            # or: jig launch -d <device>

# in another terminal, from apps/fixture
dart run jig_cli:jig ping
dart run jig_cli:jig tree
dart run jig_cli:jig tap --sem 'Overlays'
dart run jig_cli:jig swipe --key slidable_row --direction left
dart run jig_cli:jig snapshot
dart run jig_cli:jig events --since 0 --sources nav,http
dart run jig_cli:jig audit
```

## Verbs

Twenty-three verbs. Every one prints a single JSON envelope on stdout, so a shell can chain
them without parsing prose:

```json
{"ok":true,"data":{...},"seq":412,"elapsedMs":38}
{"ok":false,"error":{"code":"ELEMENT_NOT_FOUND","message":"...","hint":"..."},"seq":412}
```

Exit codes: `0` ok, `1` the command failed, `2` usage error. Three verbs also use `1`
for a verdict rather than an error - `audit --strict`, `run` and `record` - and each says
so below.

### Global options

| Option | Meaning |
|---|---|
| `-h`, `--help` | Print the usage text. After a verb, print just that verb's options: `jig tap --help` |
| `--uri <ws://host:port/token/ws>` | VM service of a running app. Accepted before or after the verb. Defaults to `$JIG_URI`, then the nearest `.jig/session.json` walking up from the current directory |

### Selectors

`find`, `tap`, `swipe`, `type`, `clear`, `adjust`, `wait` and `scroll` accept a selector.
Supply one;
the most stable first:

| Flag | Selects |
|---|---|
| `-k`, `--key <value>` | the widget whose `Key` value is this. The most stable option, and the one a test should use |
| `-s`, `--sem <label>` | the accessibility label, normalised (whitespace collapsed, case-insensitive) |
| `--text <text>` | visible text, for widgets with no label |
| `--type <WidgetType>` | the widget runtime type, e.g. `IconButton` |
| `--index <n>` | with `--type`: which match to use, `0`-based |
| `--exact` / `--no-exact` | with `--sem`: exact label match (default) or substring |

A selector that matches nothing fails `ELEMENT_NOT_FOUND` and lists nearby labels in
`candidates`. Coordinates are never accepted.

### Reference

| Verb | What it does | Options |
|---|---|---|
| `version` | Print the protocol and CLI versions. No connection needed | - |
| `launch` | Run `flutter run --machine` and publish the VM service URI to `.jig/session.json`. Foreground by design: it owns the app process. Runs `fvm flutter` when the project - or any directory above it - is FVM-pinned | `-d, --device <id>`, `-t, --target <file>`, `--flavor <name>`, `--define <K=V>` (repeatable) |
| `ping` | Protocol, sequence, buffered event count, registered readers, current route | - |
| `tree` | List actionable elements from the semantics tree | `--all` (include non-interactive nodes), `--limit <n>` (default 120), `-q <text>` (filter by key, label or value) |
| `find` | `tree` narrowed by the selector you pass, for "is it there and what is it called" | selector flags, `--all`, `--limit <n>` (default 60) |
| `tap` | Activate an element through its semantics node | selector flags, `--ref <n#>` (a handle from a previous listing), `--long` |
| `swipe` | Drag an element in a named direction. Fails `GESTURE_NO_EFFECT` when the app does not visibly change | selector flags, `--ref <n#>`, `--direction left\|right\|up\|down` (default `left`) |
| `type` | Send text to a field, focusing it first. Fails `ELEMENT_NOT_EDITABLE` if nothing editable matches | selector flags, `-v, --value <text>` (required, non-empty) |
| `clear` | Empty a field, then read it back. Fails `CLEAR_REFUSED` naming what the app put back | selector flags |
| `adjust` | Move a slider or other range control by whole steps and return the new value. Fails `ADJUST_REFUSED` when there are no steps, it is at an end, or the value did not move | selector flags, `--direction up\|down` (default `up`), `--times <n>` (default 1) |
| `screenshot` | Capture the rendered frame as a PNG file and report its path and size | `-o, --out <path>` (default `.jig/screenshot-<seq>.png`), `--pixel-ratio <n>` (default 1 = device pixels) |
| `wait` | Block until an element appears or disappears, or a Dart expression becomes true | selector flags, `--absent` (wait for it to go), `--state '<expr>'` (poll a readers-based expression instead of an element), `--timeout <secs>` (default 10) |
| `scroll` | Page a scrollable until a selector is reachable, and return its ref | selector flags, `--axis vertical\|horizontal` (default `vertical`), `--steps <n>` (budget, default 20), `--in <key\|type\|label>` (which scrollable, when there is more than one) |
| `state` | Read the values the app registered with `Jig.state(...)` | `--names a,b,c` |
| `snapshot` | Alias for `state` | `--names a,b,c` |
| `events` | Read the event bus since a sequence number | `--since <seq>` (default 0), `--limit <n>` (default 100), `--sources http,log,nav,error,state,custom` |
| `nav` | Route history: the current route and how the app got there | - |
| `back` | Leave the route the way the system back button does. Fails `BACK_REFUSED` when the app declines | - |
| `eval` | Evaluate a Dart expression inside the app isolate. Power without generics; prefer `state` | `<expression>` (positional) |
| `audit` | Report controls that no stable selector can name | `--strict` (exit `1` when any `unaddressable` is found), `--limit <n>` (default 600) |
| `run` | Execute a scenario file and report each step. Exits `1` when the scenario fails | `-f, --file <path>`, or the path as the only argument |
| `record` | Write a scenario from the verbs the app already ran. Exits `1` when it recorded nothing | `--since <seq>`, `-o, --out <path>` (stdout when omitted), `--name <name>` |
| `export` | Write a scenario as an `integration_test` Dart file. Purely local: no app and no connection | `-s, --scenario <path>` (or positional), `-e, --entry <import>` (required, e.g. `package:my_app/main.dart`), `-o, --out <path>` (stdout when omitted) |

A few behaviours that are easy to guess wrong:

```bash
# A ref is a handle, not a selector: it expires between frames.
jig tree                                    # read a ref from the output
jig tap --ref n42

# A scrollable that exposes no key still has a ref, and a drag only needs its box.
jig swipe --ref n43 --direction down

# Waiting for state rather than for an element.
jig wait --state 'Get.currentRoute == "/checkout"' --timeout 5

# Paging two axes, and naming which scrollable when there are several.
jig scroll --key second_tab_target --axis horizontal
jig scroll --key inner_39 --in inner_list

# Only fail the build when a control has no stable selector.
jig audit --strict

# Emptying a field is its own verb, because it proves the result. Typing an empty
# value is a usage error that says so.
jig clear --sem 'Nombre'

# A slider has no tap action: it steps. The step size is the control's own.
jig adjust --key rating_slider --times 2      # two steps up, and it returns the value
jig screenshot -o /tmp/form.png     # the default is .jig/screenshot-<seq>.png
```

### audit

`audit` reads the whole accessibility tree and reports what a selector cannot
reach, which is application-side debt the harness can surface but not fix:

| Finding | Severity | Means |
|---|---|---|
| `unaddressable` | error | Interactive, no label, no key: only widget type plus index names it, and that breaks when the screen changes |
| `unlabelled` | warn | Selectable by key, but invisible to a screen reader and to every label selector |
| `ambiguous` | warn | Two or more controls share a label, so `--sem` resolves to one of them silently |

It exits `0` whatever it finds, unless you pass `--strict`, which exits `1` when
any `unaddressable` control exists. That makes it usable as a gate without making
it useless as a report.

### Captures

`screenshot` captures the frame the engine composited, from the root layer, so the app
needs no `RepaintBoundary` and no overlay. Two consequences are worth knowing before you
trust one:

- The root layer works in physical pixels, so `--pixel-ratio 1` - the default - reproduces
  the device frame exactly: 1080x2400 on the fixture's emulator, in under 50 KB.
  `--pixel-ratio 2` re-renders above device resolution, for when a human wants an artifact.
- Platform surfaces are not in it. The soft keyboard, a native dialog, a webview or a
  camera preview are drawn by the OS, not by Flutter, so they are absent. What you get is
  the same surface the accessibility tree describes.

The file goes beside the session (`.jig/screenshot-<seq>.png`) unless `-o` names a path,
and the envelope reports `file`, `width`, `height` and `bytes` - never the bytes
themselves.

`clear` is the same kind of promise for text fields: it dispatches the clear and then
reads the field back, so a formatter, a mask or a controller that puts text back is
`CLEAR_REFUSED` naming what survived rather than an `ok` nobody can trust. Typing an
empty `--value` is a usage error that points at it, so one action has one spelling.

### Scenarios

`jig run` executes a JSON file of verb steps and prints one report. It stops at the
first failure and marks the rest `skipped`, so the report never looks shorter than
the scenario. `data.ok` carries the verdict and the exit code mirrors it.

```json
{
  "name": "overlays-dialog",
  "steps": [
    { "verb": "tap", "key": "show_dialog" },
    { "verb": "wait", "sem": "Dialogo", "timeoutMs": 2000 },
    { "verb": "state", "expect": { "route": "/overlays" } },
    { "verb": "tap", "key": "dialog_confirm" }
  ]
}
```
```bash
dart run jig_cli:jig run apps/fixture/scenarios/overlays-dialog.json
```

A step names its selector the way the CLI flags do (`key`, `sem`, `type` + `index`,
`text`, or `ref`). `expect` compares registered state and fails with
`EXPECTATION_FAILED` rather than `INTERNAL`, so "the app did something else" is never
confused with "jig broke". `eval` is not a step: it takes a free-form expression the
other verbs do not, and `jig eval` stays the way to run one.

**Wait for what you act on.** A scenario starts on whatever route the app is on, and a
verb acts *now*: typing into a field that the route transition has not built yet fails
with `ELEMENT_NOT_EDITABLE`, which is the correct answer rather than a bug. The pattern
is `wait` between arriving somewhere and acting on it:

```json
{ "verb": "tap", "key": "nav_/form" },
{ "verb": "wait", "sem": "Nombre", "timeoutMs": 3000 },
{ "verb": "type", "sem": "Nombre", "value": "Ana" }
```

Keep scenarios self-contained for the same reason: one that assumes it is already on
`/form` cannot be replayed from a cold start, and cannot be exported - see below.

Writing that JSON by hand means transcribing work that already happened, which is
where a scenario quietly diverges from the flow it claims to check. `jig record`
writes it instead:

```bash
dart run jig_cli:jig record --since 0 --out /tmp/flow.json --name checkout
```

It reads the verb events the app emitted and translates them into steps. An event with
no structured selector - from a runtime older than the field - is counted in
`skippedEvents` rather than guessed from its human-readable sentence: a regex-derived
selector could replay something that was never touched. Assertions are not recorded;
only the caller knows what should be true afterwards, and baking in the values seen at
record time would turn a check into a tautology.

### Taking it into `flutter test integration_test/`

A scenario only runs where `jig` and a VM service are. `jig export` writes one as an
`integration_test` file instead, so a project that already gates on
`flutter test integration_test/` can use it:

```bash
dart run jig_cli:jig export \
  --scenario apps/fixture/scenarios/form-submit.json \
  --out apps/fixture/integration_test/form_submit_test.dart \
  --entry package:jig_fixture/main.dart
```

The generated test calls the same `JigActions` the CLI drives, in-process, so it fails
for the reasons `jig run` fails rather than for new ones - a `tester.tap(find.byKey(...))`
translation would be a second harness with different semantics. It carries its own
frame helpers so it compiles wherever it is dropped, and it is a generated file: rerun
the command rather than editing it. `apps/fixture/integration_test/form_submit_test.dart`
is committed so `flutter analyze` keeps the template honest between releases.

Steps with no in-process equivalent - `ping`, `tree`, `events`, `nav` - stop the
export and are named. They describe a session, and there is no session inside the test,
so emitting a comment in their place would be a test that claims to check them.

The fixture is not a demo app. Each screen reproduces a specific way that
coordinate-based harnesses break; see [docs/fixture-matrix.md](docs/fixture-matrix.md).

## Adopting it in an app

Four changes, all behind `kDebugMode`:

```dart
// main.dart
Jig.install();

// wherever the app builds its root widget
GetMaterialApp(
  logWriterCallback: Jig.logWriter,                     // captures every printInfo
  navigatorObservers: [Jig.navigatorObserver],
  ...
);

// the base class every repository extends
class BaseRepository extends JigConnect { /* was: extends GetConnect */ }
```

And register the values an agent should be able to read:

```dart
Jig.state('cart.total', () => Get.find<CartController>().total.value);
```

Consume by git ref:

```yaml
dependencies:
  jig_flutter:
    git:
      url: https://github.com/JuanCordovaLazo/jig.git
      path: packages/jig_flutter
      ref: v1.0.0

# A git dependency resolves its own dependencies against pub.dev, where these
# packages are not published. Name every jig package the package above needs.
dependency_overrides:
  jig_protocol:
    git:
      url: https://github.com/JuanCordovaLazo/jig.git
      path: packages/jig_protocol
      ref: v1.0.0
```

An app using the GetX adapter lists `jig_getx` as the dependency and overrides both
`jig_flutter` and `jig_protocol`. Every override carries the same `ref`; mixing refs
means running two contracts at once.

During local development, override by path instead of pushing a tag.

## Why this exists

Existing harnesses tap coordinates. A coordinate is a guess that silently expires
when the app rebuilds, and it cannot know that a snackbar, a dialog or a route
transition now owns that pixel. The usual escape hatch - calling the widget's
callback directly when the pointer is ignored - skips the gesture logic and makes
the test pass while verifying nothing.

`jig` addresses elements through the accessibility tree instead, computes any
position from the widget's own render box at the instant of the action, and fails
loudly rather than falling back to a guess.

## Non-goals

- Not a production runtime. Everything is debug-only.
- No custom binding, no overlay, no animated indicators.
- No coordinate selectors. Positions are always derived, never supplied.
- No "settle" heuristic. Waits are predicates evaluated inside the app.
- No web/desktop drivers.

## Layout

```
packages/     the six published packages
apps/fixture/ the conformance app
docs/         CONTRACT.md, fixture-matrix.md
```
