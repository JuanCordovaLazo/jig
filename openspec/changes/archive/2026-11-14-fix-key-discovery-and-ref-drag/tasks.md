# Tasks

## 1. Key attribution

- [x] 1.1 Report a key on the node inside the keyed widget's subtree, walking `RenderObjectElement`s rather than `element.renderObject`
- [x] 1.2 Promote the key to the actioned node covering an identical rectangle when the keyed node cannot act
- [x] 1.3 Drop keys the framework gives itself
- [x] 1.4 Keep a keyed but actionless node in the listing

## 2. Handle resolution

- [x] 2.1 Resolve a ref through the index before falling back, so a handle is found by widget rather than by render object
- [x] 2.2 Fall back to the deepest painted box matching the node's rectangle when no widget owns it
- [x] 2.3 Scale the rectangle comparison by `devicePixelRatio`, since the semantics tree reports physical pixels

## 3. Tests

- [x] 3.1 Assert the listing reports `rating_slider` with `increase`/`decrease`
- [x] 3.2 Assert `swipe --ref` drags a scrollable that exposes no key
- [x] 3.3 Re-run `./tool/verify.sh` (169 tests, 7 wire asserts)

## 4. Documentation and device verification

- [x] 4.1 Update `docs/CONTRACT.md`, `docs/HANDOFF.md`, `docs/fixture-matrix.md` and `README.md`
- [x] 4.2 Verify on a 2560x1440 device: `find --key rating_slider`, `find --key refresh_list`, `swipe --ref` on a keyless list, and `refresh.count` 0 to 1
