import 'dart:io';

import 'package:jig_cli/jig_cli.dart';
import 'package:test/test.dart';

void main() {
  test('no command is a usage error', () async {
    expect(await runJig(<String>[]), 2);
  });

  test('an unknown command is a usage error', () async {
    expect(await runJig(<String>['bogus']), 2);
  });

  test('an unknown option is a usage error', () async {
    expect(await runJig(<String>['version', '--nope']), 2);
  });

  test('version succeeds without a connection', () async {
    expect(await runJig(<String>['version']), 0);
  });

  test('--help is help, not a usage error', () async {
    expect(await runJig(<String>['--help']), 0);
  });

  test('a verb answers --help without connecting', () async {
    // 0 rather than 1 is what proves help short-circuits before _connect.
    expect(await runJig(<String>['tap', '--help']), 0);
  });

  test('an unreachable app fails the command instead of passing', () async {
    expect(
      await runJig(<String>['--uri', 'ws://127.0.0.1:1/ws', 'ping']),
      1,
    );
  });

  test('audit is a real command: it fails on connection, not on parsing', () async {
    // 1 rather than 2 is what proves the verb is registered and dispatched. A
    // missing command would be a usage error, which is what this guards against.
    expect(
      await runJig(<String>['--uri', 'ws://127.0.0.1:1/ws', 'audit']),
      1,
    );
    expect(
      await runJig(<String>['--uri', 'ws://127.0.0.1:1/ws', 'audit', '--strict']),
      1,
    );
  });

  test('audit rejects options it does not have', () async {
    expect(await runJig(<String>['audit', '--nope']), 2);
  });

  test('run refuses a missing or malformed scenario before connecting', () async {
    // Exit 2, not 1: a scenario that does not parse is the caller's mistake and must
    // never be reported as an app that is not running.
    expect(await runJig(<String>['run']), 2);
    expect(await runJig(<String>['run', '/definitely/not/here.json']), 2);

    final broken = File('${Directory.systemTemp.path}/jig_broken_scenario.json')
      ..writeAsStringSync('{"steps":[{"verb":"teleport"}]}');
    addTearDown(broken.deleteSync);
    expect(await runJig(<String>['run', broken.path]), 2);
  });
}
