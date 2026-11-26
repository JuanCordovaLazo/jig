# The jig contract

Everything an agent sees crosses this boundary. Treat the shapes below as public
API: adding a field is a minor change, renaming or removing one is major, and a
frontend must refuse to guess when the protocol version differs.

## Envelope

Every command prints exactly one JSON object on stdout.

```json
{"ok": true, "data": {"count": 3, "elements": []}, "seq": 412, "elapsedMs": 38}
{"ok": false, "error": {"code": "ELEMENT_NOT_FOUND", "message": "..."}, "seq": 412, "elapsedMs": 38}
```

`seq` is the app's event-bus sequence at the moment the command finished. It
exists so a caller can chain:

```bash
jig tap --sem 'Pagar'        # -> {"seq": 412}
jig events --since 412       # -> everything the tap caused
```

Exit codes: `0` ok, `1` command failed, `2` usage error. A failed command still
prints the envelope, so a consumer should parse stdout before looking at the exit
code.

## Errors

| Code | Meaning | What the caller should do |
|---|---|---|
| `ELEMENT_NOT_FOUND` | Nothing matches the selector | Read `candidates`, then narrow with `--key` |
| `ELEMENT_AMBIGUOUS` | More than one node matches | Use a ref from `jig tree`, or a key |
| `ELEMENT_NOT_VISIBLE` | Found, but not actionable in the current frame | Wait for the overlay to close |
| `ELEMENT_NOT_EDITABLE` | The target is not a text field | Check the selector |
| `EVAL_FAILED` | The Dart expression is wrong, not the app | Register a reader with `Jig.state()` |
| `EXTENSION_UNAVAILABLE` | jig is not installed in this build | Call `Jig.install()` behind `kDebugMode` |
| `NOT_CONNECTED` | No session | `jig launch -d <device>` |
| `TIMEOUT` | The predicate never became true | Read `jig events` for what happened instead |
| `SCROLL_EXHAUSTED` | Paging stopped without reaching the target | Read `candidates` for what is rendered; raise `--steps` or name the scrollable |
| `BACK_REFUSED` | The app declined the back request, so no route left the stack | Nothing popped: check `jig nav`, or act on the guard first |
| `CLEAR_REFUSED` | The field was editable, the clear was dispatched, and text is still there | Read `candidates` for what survived; the app reformats it, or a mask refills it |
| `ADJUST_REFUSED` | The control cannot move as asked: no steps, already at that end, or the value did not change | Read `candidates` for the current value; reverse the direction, or use `tap` for a stepper's button |
| `GESTURE_NO_EFFECT` | The pointer path produced no change in what is rendered or in the registered state | The gesture did not reach anything. Check the element exposes what you expect, or that it is not disabled |
| `EXPECTATION_FAILED` | A scenario's `expect` saw a different value | Read `candidates` for the actual value; the app did something else, or the step before it did not do what you thought |
| `INVALID_SELECTOR` | No selector was supplied | Pass one of `--sem`, `--key`, `--type`, `--text` |
| `INVALID_ARGUMENT` | An argument is out of range, such as a `pixelRatio` of zero | Fix the argument; the selector was not the problem |
| `INTERNAL` | A bug in jig | Report it with the `hint` payload |

Error payloads carry `candidates` (nearby labels) and `hint` (a copy-pasteable
next command) whenever those exist. They are not decoration: the point of the
contract is that a failed command tells the agent what to do next, so it never
has to guess or re-derive a selector from scratch.

## Selectors

Ordered by stability. Coordinates are deliberately not a selector.

| Kind | Argument | Survives | Notes |
|---|---|---|---|
| `key` | `--key cart_item_3` | refactors, layout, copy changes | matches `ValueKey` and `GlobalKey` |
| `semantic` | `--sem 'Agregar al carrito'` | layout, refactors | the default; comes from the accessibility tree |
| `widgetType` | `--type FilledButton --index 2` | nothing meaningful | last resort before failing |
| `text` | `--text 'Enviar'` | copy | matches rendered text only |

A `ref` (`n42`) is a handle to a node in the *current* frame. It expires when the
tree rebuilds, so anything longer lived must use a selector. Every node a listing
prints is a usable handle: a keyless scrollable's node has no owning widget, and
`tap`/`swipe` resolve it by the rectangle it occupies instead.

## Elements

A listing reports what a caller can actually select with, not just what a node is
called:

```json
{"ref": "n42", "kind": "semantics", "label": "Overlays", "key": "nav_/overlays",
 "ownerType": "ListTile", "rect": {"x": 0, "y": 96, "width": 380, "height": 72},
 "actions": ["tap"], "depth": 3}
```

| Field | Meaning |
|---|---|
| `key` | The `Key` on the owning widget, when it has one, reported on the node that can *act* for that widget. A `Slider`'s node sits below the widget and a `ListView`'s scroll node sits above its viewport; when the widget's own node cannot act but another node covers the identical rectangle and can, the key is reported there. Never borrowed from an ancestor |
| `ownerType` | Runtime type of the widget that owns the node, so a control with no label - an icon-only button - is still addressable as `--type IconButton` |
| `rect` | Bounds in screen coordinates. **Informational only** |

`rect` exists so a caller can crop a screenshot, reason about layout, or explain a
failure. It is deliberately not a selector: no command accepts a position as
input, because a position a caller supplies is a guess that expires silently on
the next rebuild. Bounds are computed from the node at the instant of the listing;
they are never cached and never fed back in.

## Extensions

Registered as `ext.jig.*` on the VM service. Eleven entries; that is the whole
surface.

| Extension | Parameters | Returns |
|---|---|---|
| `ping` | - | `protocol`, `seq`, `buffered`, `state` names, `route` |
| `elements` | `interactive`, `limit`, `q` | `count`, `elements[]` |
| `tap` | `ref` \| `semantic`/`key`/`type`/`text`, `long`, `gesture=swipe` + `direction`, `action=increase`/`decrease` + `times` | `ref`, `label`, `action`; for a step, `value`, `previousValue`, `steps` |
| `type` | selector + `value`, or `clear=true` | `via` (`semantics` \| `editableText`), `text` |
| `wait` | selector + `kind` (`present`/`absent`), `timeoutMs` | `waitedMs` |
| `events` | `since`, `sources`, `limit` | `seq`, `count`, `events[]` |
| `state` | `names` (comma separated) | `count`, `values[]` |
| `nav` | - | `current`, `entries[]` |
| `back` | - | `popped`, `from`, `route` |
| `scroll` | selector + `axis` (`vertical`/`horizontal`), `steps`, `in` | `ref`, `steps`, `reason` (`found` \| `already-rendered`) |
| `screenshot` | `pixelRatio` | `format` (`png`), `width`, `height`, `bytes`, `pixelRatio`, `base64` |

`back` routes through the same entry point as the platform back button, so
`PopScope` and `canPop` are honoured and stacked modals are dismissed by the
framework's own ordering. It reports `BACK_REFUSED` when nobody popped a route -
being told "no" is the point, since a blocked pop that reported success is
indistinguishable from a working one.

`scroll` pages with the scrollable's own accessibility scroll action, between
frames, inside the UI isolate. `steps` is a budget, not a fixed count; when it runs
out or the content ends, the failure is `SCROLL_EXHAUSTED` and `candidates` lists
what was rendered. `in` names the scrollable when more than one could be paged;
without it, two candidates are `ELEMENT_AMBIGUOUS` rather than a guess.

`tap` also carries `action=increase`/`decrease`, which is what a range control advertises
instead of `tap`: it applies `times` steps and answers with the value it read back, so an
`ok` means the value really moved. A slider carries the caller's key while the node with the
step action belongs to a descendant render object, which is why the listing reports the key
on that node: the key a caller wrote is the name that appears in `jig tree`.

`type` also carries `clear=true`, the variant that empties the field and reads it back
before answering. It shares the extension because the capability is the same - set a
field's text - and only the proof differs.

`screenshot` reads the root `RenderView`'s layer, so it captures the composited frame
without the app wrapping itself in a `RepaintBoundary`. That layer lives in physical
pixels, so `pixelRatio` multiplies device pixels: `1` is the frame at device resolution.
Platform surfaces - the soft keyboard, native dialogs, webviews, camera previews - are
composited by the OS and are not in the image.

## MCP tools

`jig_mcp` serves a subset of these verbs to an agent runtime. The tool list is a public
surface on the same terms as an extension: a client's model reads `name`, `description`
and `inputSchema` and nothing else, so a terse description is a broken contract, not a
style preference.

| Rule | Why |
|---|---|
| Every tool's description says what it does, what is mandatory, what comes back and which error it produces | the model has no other manual |
| Every argument is documented, and a closed set of values is an `enum` | free strings get invented values |
| A selector verb declares its constraint as `anyOf`, never as `required` | "one of four" is not expressible with `required`, and leaving it out invites a call with no selector |
| A tool that returns pixels says so, and returns an `image` content block | text describing an image is not an image |

`packages/jig_mcp/test/tools_contract_test.dart` enforces those, so a future tool cannot be
added as a name and a handler.

Neither `initialize` nor `tools/list` touches the transport. The app is connected on the
first tool call, deliberately: a client waits on its own deadline for the handshake, and a
connect performed before it can consume that deadline entirely when the session file is
stale. A tool that cannot connect answers `NOT_CONNECTED`; a tool whose handler throws
answers an `isError` result rather than escaping the stdio loop, because a client cannot
recover from a server that exits mid-session.

`connect` is the one tool that is not a verb. It takes a `ws://` URI and rebinds the server,
which is how a client that cannot set a working directory still reaches an app.

The `initialize` result also carries `instructions`: the server-level playbook a client is
expected to put in front of the model. Descriptions are per-verb, so they cannot say that
`state` is cheaper than `screenshot` or that a screenshot cannot be asserted on - that
comparison only exists between tools, and `instructions` is the only place it can live. Its
names are checked against the served tools and `JigErrorCode`, so the playbook cannot
mention a verb that does not exist or an error that cannot happen.

## Events

```json
{"seq": 128, "source": "http", "kind": "response", "at": 1762970000000,
 "data": {"id": 4, "method": "GET", "url": "/items", "status": 200, "ms": 184}}
```

Sources: `http`, `log`, `nav`, `error`, `state`, `custom`.

Events are also mirrored through `developer.postEvent('jig.<source>', ...)` for
consumers that prefer to subscribe. The buffer is authoritative: mirrored events
are best effort and are dropped when no debugger is attached.

## State

Two ways to read app state, in order of preference:

1. **Named readers** - `Jig.state('cart.total', () => ...)`. Reliable, no source
   evaluation, one extension call for the whole snapshot.
2. **`jig eval`** - evaluates Dart against the app's root library. Useful for
   ad-hoc questions, but debug-only, needs the identifiers in scope, and fails on
   some generic instantiations. A failure here means "register a reader", not
   "the app is broken". `jig wait --state '<expression>'` polls this same path,
   one round trip per attempt, so it is markedly slower than an element wait.

## Stability rules

- `seq` is monotonic per isolate and never reused.
- Enum values are serialised through an explicit wire string (see
  `JigErrorCode.wire`), so renaming an enum arm is not a breaking change.
- New optional fields may appear at any time; consumers must ignore unknown ones.
- Removing or renaming a field, an error code, or an extension is a major bump.
