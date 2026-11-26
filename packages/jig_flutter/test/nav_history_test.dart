import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jig_flutter/jig_flutter.dart';

void main() {
  setUp(JigNavHistory.clear);

  test('records route changes and tracks the current route', () {
    JigNavHistory.record('push', route: '/a');
    JigNavHistory.record('push', route: '/b', previous: '/a');
    expect(JigNavHistory.current, '/b');
    expect(JigNavHistory.entries, hasLength(2));
  });

  test('the history is a bounded ring', () {
    for (var i = 0; i < 100; i++) {
      JigNavHistory.record('push', route: '/r$i');
    }
    expect(JigNavHistory.entries, hasLength(64));
    expect(JigNavHistory.current, '/r99');
  });

  test('the observer counts real pops so a refused back can be told apart', () {
    final observer = JigNavigatorObserver();
    final before = JigNavHistory.popCount;
    final route = MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/b'),
      builder: (_) => const SizedBox(),
    );
    observer.didPop(route, null);
    expect(JigNavHistory.popCount, before + 1);
  });
}
