import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jig_fixture/pages/home_page.dart';
import 'package:jig_fixture/pages/overlays_page.dart';
import 'package:jig_fixture/pages/slidable_page.dart';
import 'package:jig_flutter/jig_flutter.dart';
import 'package:jig_protocol/jig_protocol.dart';

import 'support/jig_harness.dart';

/// Whether an actionable node with [label] is in the tree right now.
///
/// Row 21's claim is about presence in the tree, not about a selector spelling, so
/// this is what the test asks before and after the gesture.
bool _hasAction(String label) => JigElementIndex.capture(limit: 80).any(
  (JigElement element) =>
      element.label == label && element.actions.isNotEmpty,
);

void main() {
  setUp(() {
    JigNavHistory.clear();
    Get.reset();
  });

  testWidgets('a scrollable that exposes no key is still draggable by ref', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const HomePage(), () async {
      // The home `ListView` has no key, and the node carrying its scroll actions
      // is created by a render object that no element on the page owns. A handle
      // from a listing is then the only way to name it - which is exactly what the
      // agent tried and could not do.
      final scrollable = JigElementIndex.capture().firstWhere(
        (JigElement e) => e.key == null && e.actions.contains('scrollUp'),
      );

      final swiped = await drive(
        tester,
        JigActions.swipe(
          JigSelector.key('unused'),
          direction: JigSwipeDirection.up,
          ref: scrollable.ref,
        ),
        maxFrames: 900,
      );
      expect(swiped['gesture'], 'swipe');
      expect(swiped['direction'], 'up');
    });
  });

  testWidgets('a swipe reveals an action that was not in the tree before', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const SlidablePage(), () async {
      expect(_hasAction('Delete'), isFalse);

      final swiped = await drive(
        tester,
        JigActions.swipe(
          JigSelector.key('slidable_row'),
          direction: JigSwipeDirection.left,
        ),
      );
      expect(swiped['gesture'], 'swipe');
      expect(swiped['direction'], 'left');
      await tester.pumpAndSettle();

      // Revealed. Asserted on the tree, because that is the row's claim: the key
      // on the `SlidableAction` wrapper does not reach the node, which belongs to
      // the `OutlinedButton` inside it, so the label is the handle that works.
      expect(_hasAction('Delete'), isTrue);

      final tapped = JigActions.tap(JigSelector.semantic('Delete'));
      expect(tapped['action'], 'tap');
      expect(tapped['label'], 'Delete');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      expect(find.text('delete'), findsOneWidget);
    });
  });

  testWidgets('a swipe that changes nothing fails instead of reporting ok', (
    WidgetTester tester,
  ) async {
    // A plain row with no swipe behaviour at all. The pointer path is emitted, the
    // app ignores it, and the verb must say so rather than call it a success.
    await withPage(
      tester,
      Scaffold(
        body: ListView(
          children: <Widget>[
            ListTile(
              key: const ValueKey<String>('inert_row'),
              title: const Text('Inerte'),
            ),
          ],
        ),
      ),
      () async {
        final error = await driveFailure(
          tester,
          JigActions.swipe(
            JigSelector.key('inert_row'),
            direction: JigSwipeDirection.left,
          ),
        );

        expect(error?.code, JigErrorCode.gestureNoEffect);
        expect(error?.hint, contains('Jig.state'));
      },
    );
  });

  testWidgets('a covered element fails before any pointer event is emitted', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const OverlaysPage(), () async {
      JigActions.tap(JigSelector.key('show_dialog'));
      await tester.pumpAndSettle();

      final error = await driveFailure(
        tester,
        JigActions.swipe(
          JigSelector.key('overlay_target'),
          direction: JigSwipeDirection.left,
        ),
      );

      // `elementNotVisible`, and not `gestureNoEffect`: the hit test runs before
      // anything is dispatched, so the verb never pretended the gesture happened.
      // If events were emitted and simply missed, the code would be the other one.
      expect(error?.code, JigErrorCode.elementNotVisible);
      expect(error?.message, contains('covered'));

      JigActions.tap(JigSelector.key('dialog_confirm'));
      await tester.pumpAndSettle();
    });
  });
}
