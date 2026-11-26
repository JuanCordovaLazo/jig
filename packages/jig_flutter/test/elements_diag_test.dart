import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// The handler is not exported by the barrel; importing it from inside the package
// that owns it is how the payload is reached without widening the public surface.
import 'package:jig_flutter/src/extensions.dart';

void main() {
  Future<void> mount(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pump();
  }

  testWidgets('zero rows are never reported without the fields that explain it', (
    WidgetTester tester,
  ) async {
    await mount(
      tester,
      const Scaffold(body: Center(child: Text('solo texto'))),
    );

    final payload = await JigExtensions.elements(<String, String>{});
    expect(payload['count'], 0);
    expect(payload['elements'], isEmpty);

    final diag = payload['diag']! as Map<String, Object?>;
    // Every field a caller needs to tell "semantics never came up" from "the
    // screen really has nothing to act on" from "the tree has no root".
    expect(
      diag.keys,
      containsAll(<String>[
        'semanticsEnabled',
        'handles',
        'views',
        'trees',
        'nodeCount',
        'actionableCount',
      ]),
    );
    expect(diag['views'], greaterThan(0));
    expect(diag['actionableCount'], 0);
  });

  testWidgets('a page with no actionable node still explains itself', (
    WidgetTester tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await mount(
        tester,
        const Scaffold(body: Center(child: Text('solo texto'))),
      );

      final payload = await JigExtensions.elements(<String, String>{});
      expect(payload['elements'], isEmpty);

      final diag = payload['diag']! as Map<String, Object?>;
      expect(diag['semanticsEnabled'], isTrue);
      expect(diag['trees'], greaterThan(0));
      expect(diag['nodeCount'], greaterThan(0));
      expect(diag['actionableCount'], 0);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('rows come back and the reason block stays attached', (
    WidgetTester tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await mount(
        tester,
        Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('Pulsar'),
            ),
          ),
        ),
      );

      final payload = await JigExtensions.elements(<String, String>{});
      expect(payload['count'], greaterThan(0));
      expect(payload['diag'], isA<Map<String, Object?>>());
    } finally {
      handle.dispose();
    }
  });

  testWidgets('q finds an element by its key, not only by label', (
    WidgetTester tester,
  ) async {
    await mount(
      tester,
      Scaffold(
        body: ListView(
          children: const <Widget>[
            ListTile(
              key: ValueKey<String>('nav_/slidable'),
              title: Text('Swipe actions'),
              onTap: _noop,
            ),
          ],
        ),
      ),
    );

    // A caller who already knows the key has no other way to ask. Searching label
    // and value alone answered this with nothing while the tile was on screen.
    final found = await JigExtensions.elements(<String, String>{'q': 'slid'});
    expect(found['count'], 1);

    final byLabel = await JigExtensions.elements(<String, String>{'q': 'swipe'});
    expect(byLabel['count'], 1);

    final missing = await JigExtensions.elements(<String, String>{'q': 'nothing'});
    expect(missing['count'], 0);
  });
}

void _noop() {}
