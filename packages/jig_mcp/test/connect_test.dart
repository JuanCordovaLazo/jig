import 'dart:io';

import 'package:jig_cli/jig_cli.dart';
import 'package:jig_mcp/jig_mcp.dart';
import 'package:test/test.dart';

/// The server and the CLI have to agree about which URI wins, because they are two
/// entry points into the same session. `.mcp.json` cannot prompt, so the environment
/// is the only channel a portable config has - that is what `JIG_URI` is for here.
void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('jig_mcp_connect_'));
  tearDown(() => root.deleteSync(recursive: true));

  test('the flag wins over everything else', () {
    JigSession(
      uri: 'ws://from-session/ws',
      startedAt: 'now',
    ).write(JigSession.fileFor(root));

    expect(
      resolveServerUri(
        flag: 'ws://from-flag/ws',
        environment: <String, String>{'JIG_URI': 'ws://from-env/ws'},
        from: root,
      ),
      'ws://from-flag/ws',
    );
  });

  test('the environment wins over the session file', () {
    JigSession(
      uri: 'ws://from-session/ws',
      startedAt: 'now',
    ).write(JigSession.fileFor(root));

    expect(
      resolveServerUri(
        environment: <String, String>{'JIG_URI': 'ws://from-env/ws'},
        from: root,
      ),
      'ws://from-env/ws',
    );
  });

  test('the session file is the last resort', () {
    JigSession(
      uri: 'ws://from-session/ws',
      startedAt: 'now',
    ).write(JigSession.fileFor(root));

    expect(
      resolveServerUri(environment: const <String, String>{}, from: root),
      'ws://from-session/ws',
    );
  });

  test('nothing configured is null, not an empty string', () {
    // The bin turns null into an offline server that still answers; an empty URI
    // would instead look like a connection to nowhere.
    expect(
      resolveServerUri(environment: const <String, String>{}, from: root),
      isNull,
    );
    expect(
      resolveServerUri(
        environment: const <String, String>{'JIG_URI': ''},
        from: root,
      ),
      isNull,
    );
  });

  test('an empty flag does not shadow the environment', () {
    expect(
      resolveServerUri(
        flag: '',
        environment: <String, String>{'JIG_URI': 'ws://from-env/ws'},
        from: root,
      ),
      'ws://from-env/ws',
    );
  });
}
