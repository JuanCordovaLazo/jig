import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jig_fixture/controllers.dart';
import 'package:jig_fixture/pages/live_list_page.dart';
import 'package:jig_flutter/jig_flutter.dart';
import 'package:jig_protocol/jig_protocol.dart';

import 'support/jig_harness.dart';

void main() {
  setUp(() {
    JigNavHistory.clear();
    Get.reset();
    Get.put(FeedController());
  });

  tearDown(Get.reset);

  testWidgets('a tap lands on the named row while the list is reordering', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const LiveListPage(), () async {
      JigActions.tap(JigSelector.key('toggle_shuffle'));
      // Rows swap every 120 ms. This is the window in which a position resolved
      // before the action belongs to a different row.
      await tester.pump(const Duration(milliseconds: 600));

      final result = JigActions.tap(JigSelector.key('row_3'));

      // The claim is not "a tap happened": it is that the row the caller named is
      // the row that received it, after the list moved underneath.
      expect(result['action'], 'tap');
      expect(result['label'], 'Fila 3');

      // Stop the shuffle so its periodic timer does not outlive the test.
      JigActions.tap(JigSelector.key('toggle_shuffle'));
      await tester.pump();
    });
  });
}
