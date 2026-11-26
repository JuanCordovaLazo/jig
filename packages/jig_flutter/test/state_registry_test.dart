import 'package:flutter_test/flutter_test.dart';
import 'package:jig_flutter/jig_flutter.dart';

enum _Mode { on }

void main() {
  setUp(JigStateRegistry.clear);

  test('a throwing reader is reported in place, not fatal', () {
    JigStateRegistry.register('ok', () => 1);
    JigStateRegistry.register('bad', () => throw StateError('nope'));

    final snapshot = JigStateRegistry.snapshot();
    expect(snapshot['ok']!.value, 1);
    expect(snapshot['bad']!.error, contains('nope'));
  });

  test('an unknown name is reported as not registered', () {
    final snapshot = JigStateRegistry.snapshot(only: <String>['missing']);
    expect(snapshot['missing']!.error, 'not registered');
  });

  test('values are coerced to something jsonEncode accepts', () {
    JigStateRegistry.register('mode', () => _Mode.on);
    JigStateRegistry.register('list', () => <Object>[_Mode.on, 2]);
    final snapshot = JigStateRegistry.snapshot();
    expect(snapshot['mode']!.value, 'on');
    expect(snapshot['list']!.value, <Object?>['on', 2]);
  });

  test('unregister removes a reader', () {
    JigStateRegistry.register('x', () => 1);
    JigStateRegistry.unregister('x');
    expect(JigStateRegistry.names, isEmpty);
  });
}
