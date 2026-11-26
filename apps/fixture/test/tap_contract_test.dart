import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jig_fixture/pages/opaque_page.dart';
import 'package:jig_fixture/pages/overlays_page.dart';
import 'package:jig_flutter/jig_flutter.dart';
import 'package:jig_protocol/jig_protocol.dart';

import 'support/jig_harness.dart';

/// A page with nothing but a button, so the harness mechanics are proved without
/// dragging GetX's snackbar timers into the assertion.
Widget _smokePage(void Function() onTap) => Scaffold(
  body: Center(
    child: ElevatedButton(
      key: const ValueKey<String>('smoke_target'),
      onPressed: onTap,
      child: const Text('Pulsar'),
    ),
  ),
);

void main() {
  setUp(JigNavHistory.clear);

  testWidgets('a tap reaches the widget and reports the node it used', (
    WidgetTester tester,
  ) async {
    var taps = 0;
    await withPage(tester, _smokePage(() => taps++), () async {
      final result = JigActions.tap(JigSelector.key('smoke_target'));

      expect(taps, 1);
      expect(result['action'], 'tap');
      expect(result['ref'], startsWith('n'));
      expect(result['label'], 'Pulsar');
    });
  });

  testWidgets('a target behind a modal barrier fails instead of reporting ok', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const OverlaysPage(), () async {
      JigActions.tap(JigSelector.key('show_dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Dialogo'), findsOneWidget);

      // The button is still on screen at the same position, so a coordinate-based
      // tap would land on the barrier and could report success.
      final error = errorOf(
        attempt(() => JigActions.tap(JigSelector.key('overlay_target'))),
      );

      expect(error?.code, JigErrorCode.elementNotVisible);
      expect(find.text('Tocado'), findsNothing);

      JigActions.tap(JigSelector.key('dialog_confirm'));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('a bottom sheet is reachable while it is the topmost surface', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const OverlaysPage(), () async {
      JigActions.tap(JigSelector.key('show_sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Hoja inferior'), findsOneWidget);

      final result = JigActions.tap(JigSelector.key('sheet_close'));
      expect(result['action'], 'tap');

      await tester.pumpAndSettle();
      expect(find.text('Hoja inferior'), findsNothing);
    });
  });

  testWidgets('a tappable that never opted into semantics is not visible', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const OpaquePage(), () async {
      final error = errorOf(
        attempt(() => JigActions.tap(JigSelector.key('opaque_target'))),
      );

      expect(error?.code, JigErrorCode.elementNotVisible);

      // The labelled sibling on the same screen is reachable, so the failure above
      // is about semantics and not about the page being unreadable.
      expect(
        JigActions.tap(JigSelector.key('labelled_target'))['action'],
        'tap',
      );
    });
  });
}
