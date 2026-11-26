# Design

## A bundle assertion, not a golden image

A golden would also catch it, and it would drag font rendering into the gate: any
Impeller/Skia or Flutter bump re-bakes the pixels and the test fails for a reason
unrelated to what it guards. What actually went wrong is narrower - the asset was not in
the bundle - so the test asserts exactly that by loading the font from `rootBundle`.

Widget tests read the same asset manifest the app is built with, so the assertion is real
without a device: removing `uses-material-design` fails it, and that is the regression
this exists for.

## The screenshot stays the proof of appearance

The bundle test cannot tell whether a glyph looks right, only that a font is there. That
split is deliberate: the automated guard covers the mechanical absence, and the device
capture - stored in the verification notes - covers what a person sees.
