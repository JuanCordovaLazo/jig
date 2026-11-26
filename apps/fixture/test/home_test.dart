import 'package:flutter_test/flutter_test.dart';
import 'package:jig_fixture/pages/home_page.dart';
import 'package:jig_flutter/jig_flutter.dart';
import 'package:jig_protocol/jig_protocol.dart';

import 'support/jig_harness.dart';

void main() {
  setUp(JigNavHistory.clear);

  testWidgets('an unlabelled IconButton is still addressable by type and index', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const HomePage(), () async {
      // Neither app-bar button carries a label, which is the row's subject: a
      // label-only listing cannot name one of these at all. The documented
      // workaround is type plus index, so that is what has to keep working.
      final result = JigActions.tap(
        JigSelector.widgetType('IconButton', index: 1),
      );
      expect(result['action'], 'tap');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      expect(find.text('trailing'), findsOneWidget);
    });
  });
}
