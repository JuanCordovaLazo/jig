import 'package:jig_driver/jig_driver.dart';
import 'package:test/test.dart';

void main() {
  test('eval result omits the value when it failed', () {
    expect(
      const JigEvalResult(ok: false, error: 'boom').toJson(),
      <String, Object?>{'ok': false, 'error': 'boom'},
    );
    expect(
      const JigEvalResult(ok: true, value: 'true', kind: 'String').toJson(),
      <String, Object?>{'ok': true, 'value': 'true', 'kind': 'String'},
    );
  });

  test('attaching to nothing raises a connection exception', () {
    expect(
      JigConnection.attach('ws://127.0.0.1:1/ws'),
      throwsA(isA<JigConnectionException>()),
    );
  });
}
