import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jig_fixture/pages/back_gate_page.dart';
import 'package:jig_flutter/jig_flutter.dart';
import 'package:jig_protocol/jig_protocol.dart';

import 'support/jig_harness.dart';

/// Opens [BackGatePage] on top of a root route, so leaving it is a real pop of a
/// real stack rather than popping the only route.
Widget _rootWithGate() => Builder(
  builder: (BuildContext context) => Scaffold(
    body: Center(
      child: ElevatedButton(
        key: const ValueKey<String>('open_gate'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/back-gate'),
            builder: (BuildContext context) => const BackGatePage(),
          ),
        ),
        child: const Text('Abrir puerta'),
      ),
    ),
  ),
);

void main() {
  setUp(JigNavHistory.clear);

  testWidgets('a refused back is reported as refused, not as a pop', (
    WidgetTester tester,
  ) async {
    await withPage(tester, _rootWithGate(), () async {
      JigActions.tap(JigSelector.key('open_gate'));
      await tester.pumpAndSettle();
      expect(find.text('Back gate'), findsOneWidget);

      // The app guards unsaved input: it answers the request but nothing leaves
      // the stack. `handlePopRoute` returns true here, so believing that value is
      // exactly the silent lie this check exists to catch.
      final refused = await driveFailure(tester, JigActions.back());
      expect(refused?.code, JigErrorCode.backRefused);
      expect(find.text('Back gate'), findsOneWidget);

      // Confirming lifts the guard, and the next request really does pop.
      JigActions.tap(JigSelector.key('confirm_leave'));
      await tester.pumpAndSettle();

      final popped = await drive(tester, JigActions.back());
      expect(popped['popped'], isTrue);

      // The route is removed when the pop starts; the exit animation still has to
      // run before the screen is really gone.
      await tester.pumpAndSettle();
      expect(find.text('Back gate'), findsNothing);
    });
  });
}
