import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jig_fixture/controllers.dart';
import 'package:jig_fixture/pages/refresh_page.dart';
import 'package:jig_flutter/jig_flutter.dart';
import 'package:jig_protocol/jig_protocol.dart';

import 'support/jig_harness.dart';

void main() {
  late RefreshController refreshes;

  setUp(() {
    JigNavHistory.clear();
    Get.reset();
    refreshes = Get.put(RefreshController());
    Jig.state('refresh.count', () => refreshes.count.value);
  });

  tearDown(() {
    JigStateRegistry.unregister('refresh.count');
    Get.reset();
  });

  testWidgets('a downward swipe at the top refreshes, and the count proves it', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const RefreshPage(), () async {
      expect(refreshes.count.value, 0);

      // The scrollable, not a row: pull-to-refresh needs a drag measured against the
      // viewport (a 56 px row moved by 80% of its own height is far short of the
      // indicator's threshold), and the geometry still comes from the element.
      final swiped = await drive(
        tester,
        JigActions.swipe(
          JigSelector.key('refresh_list'),
          direction: JigSwipeDirection.down,
        ),
        maxFrames: 900,
      );
      expect(swiped['gesture'], 'swipe');
      expect(swiped['direction'], 'down');

      // `onRefresh` awaits 400 ms before recording, so the indicator has to finish.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(refreshes.count.value, 1);

      // The count is read through the registered reader, which is what an agent
      // would do - not through the widget tree, where nothing shows it.
      final snapshot = JigStateRegistry.snapshot(only: <String>['refresh.count']);
      expect(snapshot['refresh.count']?.value, 1);
      expect(find.text('1'), findsNothing);
    });
  });

  testWidgets('a swipe that cannot refresh does not bump the count', (
    WidgetTester tester,
  ) async {
    // Same geometry, but a plain list with no indicator: the counter stays at zero
    // and the verb has to say the gesture did nothing.
    await withPage(
      tester,
      Scaffold(
        body: ListView(
          children: <Widget>[
            ListTile(
              key: const ValueKey<String>('plain_row_0'),
              title: const Text('Sin refresco'),
            ),
          ],
        ),
      ),
      () async {
        final error = await driveFailure(
          tester,
          JigActions.swipe(
            JigSelector.key('plain_row_0'),
            direction: JigSwipeDirection.down,
          ),
        );

        expect(error?.code, JigErrorCode.gestureNoEffect);
        expect(refreshes.count.value, 0);
      },
    );
  });
}
