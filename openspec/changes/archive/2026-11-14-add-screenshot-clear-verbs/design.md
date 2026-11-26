# Design

## Capture from the root layer, not a RepaintBoundary

`RenderRepaintBoundary.toImage` needs a boundary the app does not necessarily have,
and asking apps to wrap themselves for the harness is the kind of instrumentation
this project avoids. `RendererBinding.instance.renderViews` gives the root
`RenderView`, whose `layer` is a `TransformLayer` - an `OffsetLayer` - so
`toImage(paintBounds, pixelRatio:)` captures the frame the engine actually composited,
with no widget change and no overlay.

The consequence is worth stating because it bounds the claim: platform views (native
dialogs, webviews, camera previews) are not in the image. What is reported is the
Flutter frame, which is the same surface the accessibility tree describes.

## `pixelRatio` defaults to 1, and 1 is already device resolution

`RenderView` works in physical pixels - the root layer applies the device pixel ratio as a
transform - so `paintBounds` is the frame at device resolution and `pixelRatio: 1`
reproduces it exactly. Measured on the fixture: ratio 1 gives 1080x2400 in 49 KB, ratio 2
gives 2160x4800 in 117 KB. The assumption that mattered here was that a default of 1
would need a downscale to stay readable; it does not, because the frame is already the one
the device drew. `--pixel-ratio 2` is a re-render above device resolution, for a human who
wants an artifact.

The capture also excludes platform surfaces - the soft keyboard, native dialogs, webviews,
camera previews - because they are composited by the OS rather than by Flutter. That is
why the device screenshot and the jig capture of the same screen differ by the keyboard.

## The CLI writes a file; the MCP tool returns inline bytes

A base64 blob in a shell envelope is unreadable and cannot be piped anywhere useful,
while a path can be opened, diffed and attached. MCP is the opposite: a client renders
an `image` content block directly, and handing it a path would make it do a second
fetch that may not even share a filesystem.

Same extension, two presentations. The CLI drops `base64` from its envelope and keeps
`file`; the MCP server keeps the bytes and adds a text block for the dimensions.

## `clear` fails rather than guessing, and `type` refuses to empty

One action, one spelling: `type --value ''` becomes a usage error naming `clear`.
Otherwise the unproven path stays the convenient one and the proof is decorative.

`clear` resolves the field exactly as `type` does, dispatches `setText('')`, waits a
frame, then re-reads the value - from the semantics node if that is how the field was
reached, from the `EditableTextState` otherwise. Non-empty means `CLEAR_REFUSED` with
the remaining text in the message, because "it is still there" is the useful part.

`JigActions.typeText` stays permissive: it is a primitive that sets text to a string.
The refusal belongs to the caller-facing verbs, where a usage error is the right
answer.

## `screenshot` is not a scenario step and is not recorded

A scenario is a list of actions and assertions that mean the same thing on every
replay. A capture produces an artifact that no replay checks, so a `screenshot` step
would be a step that can never fail - and the export would have to refuse it, which
is how the exporter already treats `ping` and `tree`. Capture belongs to the CLI and
the MCP tool, both of which a scenario cannot call anyway.

## `CLEAR_REFUSED` instead of a reused code

`ELEMENT_NOT_EDITABLE` means the selector is wrong and `INTERNAL` means jig is broken;
neither is true. The branchable fact is "the field is editable, the app kept the
text", and the caller's next move - read the field, or act on what holds it - is
different from both.

## Configuration lives in the fixture, not the repository root

The root package is a workspace, not an app: opening it in VS Code should not start a
server that needs a running app. `apps/fixture/.vscode/mcp.json` is the project-level
example, next to the app the tools talk to, and the README shows the same JSON for
copy-paste. `.gitignore` keeps `.vscode/` out of the tree, so the file needs an
exception; the pattern has to match the directory's contents (`**/.vscode/*`) rather
than the directory, because git cannot re-include a file inside an excluded directory.
