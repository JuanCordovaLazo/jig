import 'package:flutter/widgets.dart';

/// Page padding that leaves the bottom system inset uncovered.
///
/// Android 15 and later draw the app behind the navigation bar, and Flutter reports
/// that band as `MediaQuery.viewPadding.bottom`. A scroll view adds the inset itself
/// - but only while its `padding` is null, so writing a constant silently replaces it
/// and the last row ends up under the bar on exactly the devices that enforce
/// edge-to-edge. Deriving the bottom value keeps the constant where it means
/// something and the inset where it must be honoured.
///
/// Measured on a 1080x2400 device at 420dpi: the bar is 126px (48dp), and without
/// this the last row of the home list stops 84px inside it.
EdgeInsets pagePadding(BuildContext context, {double all = 16}) {
  final bottom = MediaQuery.viewPaddingOf(context).bottom;
  return EdgeInsets.fromLTRB(all, all, all, all + bottom);
}
