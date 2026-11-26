# Design

## Derive the bottom value, do not wrap in SafeArea

`SafeArea` would also clear the bar, and it would inset the scroll *viewport*, so content
would stop at the bar instead of scrolling under it. Edge-to-edge is supposed to look like
the content continues behind the bar; what must not happen is the last item being
unreachable. Padding the content keeps both: the surface is full-bleed and the last row
stops 16dp above the bar.

`viewPadding` rather than `padding` because the keyboard should not lift the list's
bottom padding on top of the resize the Scaffold already performs: `padding.bottom` drops
to zero when the IME covers it, `viewPadding.bottom` does not.

## A test with a simulated view, not a golden

The failure is geometric and cheap to state: with a 126px bottom inset the last row's
bottom must be `<= 914.28 - 48` logical pixels. `tester.view.padding` sets that geometry
without a device, so the guard runs in the gate. It was confirmed to fail with the old
constant and pass with the helper.

The snackbar needs no fix and gets no test: GetX wraps it in `SafeArea(top: true, minimum:
padding.top)`, and a widget test with the same 63px inset measured its first line below
24dp. An added `margin` only pushed it further down without removing an overlap, so it was
removed rather than kept as decoration.
