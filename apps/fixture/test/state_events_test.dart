import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jig_fixture/controllers.dart';
import 'package:jig_flutter/jig_flutter.dart';
import 'package:jig_protocol/jig_protocol.dart';

import 'support/jig_harness.dart';

void main() {
  setUp(() {
    JigNavHistory.clear();
    Get.reset();
    Get.put(CartController());
  });

  tearDown(() {
    JigStateRegistry.unregister('cart.count');
    JigStateRegistry.unregister('cart.total');
    Get.reset();
  });

  testWidgets('registered readers expose state the widget tree cannot show', (
    WidgetTester tester,
  ) async {
    Jig.state('cart.count', () => Get.find<CartController>().count.value);
    Jig.state('cart.total', () => Get.find<CartController>().total.value);

    // A page that renders neither number, so the values below can only come from
    // the readers and not from something already on screen.
    await withPage(
      tester,
      const Scaffold(body: Center(child: Text('sin estado visible'))),
      () async {
        Get.find<CartController>().add(2.5);

        final snapshot = JigStateRegistry.snapshot(
          only: <String>['cart.count', 'cart.total'],
        );

        expect(snapshot['cart.count']?.value, 1);
        expect(snapshot['cart.total']?.value, 2.5);
        expect(find.text('2.5'), findsNothing);
      },
    );
  });

  test('a high-volume log still yields a bounded, filtered window', () {
    final bus = JigBus.instance;
    final start = bus.seq;

    for (var line = 0; line < 3000; line++) {
      Jig.logWriter('linea $line');
    }

    final window = bus.since(start, sources: {JigSource.log}, limit: 20);

    // Volume must not drown the signal: the window is bounded by the caller's
    // limit, holds only the source asked for, and starts after the mark.
    expect(window, hasLength(20));
    expect(window.every((JigEvent event) => event.source == JigSource.log), isTrue);
    expect(window.first.seq, greaterThan(start));
    expect(window.last.seq, greaterThan(window.first.seq));
  });
}
