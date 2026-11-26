import 'package:flutter_test/flutter_test.dart';
import 'package:jig_fixture/pages/nested_scroll_page.dart';
import 'package:jig_fixture/pages/scroll_page.dart';
import 'package:jig_fixture/pages/sliver_page.dart';
import 'package:jig_fixture/pages/tabs_page.dart';
import 'package:jig_flutter/jig_flutter.dart';
import 'package:jig_protocol/jig_protocol.dart';

import 'support/jig_harness.dart';

void main() {
  setUp(JigNavHistory.clear);

  testWidgets('a row that is not rendered is not found, and paging reaches it', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const ScrollPage(), () async {
      final miss = errorOf(
        attempt(() => JigActions.tap(JigSelector.key('item_450'))),
      );
      expect(miss?.code, JigErrorCode.elementNotFound);

      final scrolled = await drive(
        tester,
        JigActions.scrollUntil(JigSelector.key('item_450'), steps: 200),
        maxFrames: 6000,
      );
      expect(scrolled['reason'], 'found');
      expect(scrolled['ref'], startsWith('n'));

      final acted = JigActions.tapRef(scrolled['ref']! as String);
      expect(acted['label'], 'Elemento 450');
    });
  });

  testWidgets('a spent step budget says so instead of claiming the end', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const ScrollPage(), () async {
      final error = await driveFailure(
        tester,
        JigActions.scrollUntil(JigSelector.key('item_99999'), steps: 3),
      );

      expect(error?.code, JigErrorCode.scrollExhausted);
      expect(error?.message, contains('Budget of 3 step(s)'));
    });
  });

  testWidgets('two scrollables on one screen are ambiguous until one is named', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const NestedScrollPage(), () async {
      final ambiguous = await driveFailure(
        tester,
        JigActions.scrollUntil(JigSelector.key('inner_39')),
      );

      expect(ambiguous?.code, JigErrorCode.elementAmbiguous);
      expect(ambiguous?.candidates, contains('inner_list'));

      final named = await drive(
        tester,
        JigActions.scrollUntil(JigSelector.key('inner_39'), within: 'inner_list'),
      );
      expect(named['reason'], 'found');
      expect(JigActions.tapRef(named['ref']! as String)['label'], 'Inner 39');
    });
  });

  testWidgets('a sliver viewport is paged by its own scroll node', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const SliverPage(), () async {
      final miss = errorOf(
        attempt(() => JigActions.tap(JigSelector.key('sliver_55'))),
      );
      expect(miss?.code, JigErrorCode.elementNotFound);

      final scrolled = await drive(
        tester,
        JigActions.scrollUntil(JigSelector.key('sliver_55')),
      );
      expect(scrolled['reason'], 'found');
      expect(JigActions.tapRef(scrolled['ref']! as String)['label'], 'Sliver 55');
    });
  });

  testWidgets('horizontal paging needs the axis to be named', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const TabsPage(), () async {
      final vertical = await driveFailure(
        tester,
        JigActions.scrollUntil(JigSelector.key('second_tab_target')),
      );
      expect(vertical?.code, JigErrorCode.elementNotVisible);

      final horizontal = await drive(
        tester,
        JigActions.scrollUntil(
          JigSelector.key('second_tab_target'),
          horizontal: true,
        ),
      );
      expect(horizontal['reason'], 'found');
      expect(
        JigActions.tapRef(horizontal['ref']! as String)['label'],
        'Second tab target',
      );
    });
  });

  testWidgets('a modal over the list makes paging fail, not guess', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const ScrollPage(), () async {
      JigActions.tap(JigSelector.key('scroll_open_dialog'));
      await tester.pumpAndSettle();

      final error = await driveFailure(
        tester,
        JigActions.scrollUntil(JigSelector.key('item_450')),
      );
      expect(error?.code, JigErrorCode.elementNotVisible);

      JigActions.tap(JigSelector.key('scroll_dialog_close'));
      await tester.pumpAndSettle();
    });
  });
}
