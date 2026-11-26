import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jig_fixture/controllers.dart';
import 'package:jig_fixture/pages/stacked_dialogs_page.dart';
import 'package:jig_flutter/jig_flutter.dart';
import 'package:jig_protocol/jig_protocol.dart';

import 'support/jig_harness.dart';

void main() {
  setUp(() {
    JigNavHistory.clear();
    Get.reset();
    Get.put(DialogController());
    Jig.state('dialog.result', () => Get.find<DialogController>().lastResult.value);
  });

  tearDown(() {
    JigStateRegistry.unregister('dialog.result');
    Get.reset();
  });

  testWidgets('back peels one modal at a time and leaves the route in place', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const StackedDialogsPage(), () async {
      JigActions.tap(JigSelector.key('open_dialog'));
      await tester.pumpAndSettle();
      JigActions.tap(JigSelector.key('dialog_open_sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Stacked dialogs'), findsWidgets);

      // First back removes the sheet only: a harness that tears the whole route
      // down here would lose the dialog the caller is still working in.
      final first = await drive(tester, JigActions.back());
      expect(first['popped'], isTrue);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('sheet_panel')), findsNothing);
      expect(find.byKey(const ValueKey<String>('dialog_confirm')), findsOneWidget);

      // Second back removes the dialog, and the page underneath survives.
      final second = await drive(tester, JigActions.back());
      expect(second['popped'], isTrue);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('dialog_confirm')), findsNothing);
      expect(find.byKey(const ValueKey<String>('open_dialog')), findsOneWidget);
    });
  });

  testWidgets('a dialog result lands in the registered reader', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const StackedDialogsPage(), () async {
      JigActions.tap(JigSelector.key('open_dialog'));
      await tester.pumpAndSettle();

      JigActions.tap(JigSelector.key('dialog_confirm'));
      await tester.pumpAndSettle();

      final snapshot = JigStateRegistry.snapshot(only: <String>['dialog.result']);
      expect(snapshot['dialog.result']?.value, 'confirmed');
    });
  });
}
