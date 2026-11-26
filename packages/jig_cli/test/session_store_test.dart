import 'dart:io';

import 'package:jig_cli/jig_cli.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('jig_session_'));
  tearDown(() => root.deleteSync(recursive: true));

  test('a written session reads back', () {
    final file = JigSession.fileFor(root);
    const JigSession(
      uri: 'ws://127.0.0.1:1/ws',
      startedAt: 'now',
      pid: 7,
      target: 'lib/main.dart',
    ).write(file);

    final session = JigSession.read(file)!;
    expect(session.uri, 'ws://127.0.0.1:1/ws');
    expect(session.pid, 7);
    expect(session.target, 'lib/main.dart');
  });

  test('a corrupt or uri-less file is treated as no session', () {
    final file = JigSession.fileFor(root)..parent.createSync(recursive: true);
    file.writeAsStringSync('not json');
    expect(JigSession.read(file), isNull);
    file.writeAsStringSync('{"uri": ""}');
    expect(JigSession.read(file), isNull);
    file.writeAsStringSync('[1]');
    expect(JigSession.read(file), isNull);
  });

  test('discover walks up to the nearest session file', () {
    const JigSession(uri: 'ws://x', startedAt: '').write(
      JigSession.fileFor(root),
    );
    final nested = Directory('${root.path}/a/b')..createSync(recursive: true);

    expect(
      JigSession.discover(from: nested)?.path,
      JigSession.fileFor(root).path,
    );
  });

  test('discover returns null when there is no session', () {
    expect(JigSession.discover(from: root), isNull);
  });
}
