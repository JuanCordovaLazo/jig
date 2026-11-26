import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jig_fixture/pages/home_page.dart';
import 'package:jig_flutter/jig_flutter.dart';

import 'support/jig_harness.dart';

/// Android 15 and later draw the app behind the system bars, and the fixture's
/// pages used to write their padding as a constant - which replaces the inset a
/// scroll view derives from `MediaQuery` and leaves the last row under the
/// navigation bar. These two checks are the ones a screenshot cannot make.
///
/// The device this was measured on is 1080x2400 at 420dpi: a 63px status bar and a
/// 126px navigation bar, which is 24dp and 48dp.
void main() {
  setUp(JigNavHistory.clear);

  testWidgets('the first row starts below the status bar', (
    WidgetTester tester,
  ) async {
    await _phone(tester);
    await withPage(tester, const HomePage(), () async {
      final first = tester.getRect(
        find.byKey(const ValueKey<String>('nav_/overlays')),
      );

      // 63px at 2.625 is 24dp of status bar; the AppBar must put its content under
      // that, not behind it.
      expect(first.top, greaterThanOrEqualTo(24));
    });
  });

  testWidgets('the last row clears the navigation bar at full scroll', (
    WidgetTester tester,
  ) async {
    await _phone(tester);
    await withPage(tester, const HomePage(), () async {
      // 126px at 2.625 is 48dp of navigation bar, which is the band the content
      // must not end in.
      const navBar = 48.0;
      const screenHeight = 2400 / 2.625;

      await tester.drag(
        find.byType(ListView),
        const Offset(0, -10000),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      final last = tester.getRect(
        find.byKey(const ValueKey<String>('nav_/slidable')),
      );
      expect(last.bottom, lessThanOrEqualTo(screenHeight - navBar));
    });
  });
}

/// Puts the test view on the geometry the defect was measured on.
Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  tester.view.padding = const FakeViewPadding(top: 63, bottom: 126);
  tester.view.viewPadding = const FakeViewPadding(top: 63, bottom: 126);
  addTearDown(tester.view.reset);
}
