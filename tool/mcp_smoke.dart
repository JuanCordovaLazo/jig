// A black-box check of the MCP server over the wire it actually uses.
//
// The unit tests drive `JigMcpServer.handle` with maps, which is the right way to
// test the protocol layer but cannot see the two failures that made the server
// unusable in an editor: a handshake that waited on the transport, and a handler
// whose exception ended the process. Both are properties of the spawned process, so
// this script spawns it and speaks stdio JSON-RPC to it, exactly as a client does.
//
// It needs no app, no device and no session file: every assert is about what the
// server does when the app is absent, which is the state an editor finds it in.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const Duration _handshakeBudget = Duration(seconds: 3);
const Duration _replyBudget = Duration(seconds: 20);

var _failures = 0;

void _pass(String what) => stdout.writeln('  ok   $what');

void _fail(String what, Object detail) {
  _failures++;
  stdout.writeln('  FAIL $what');
  for (final line in '$detail'.split('\n')) {
    stdout.writeln('       $line');
  }
}

/// One server process, as a client sees it.
final class _Server {
  _Server(this._process) {
    _process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_onLine);
    _process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((String line) => _stderr.write('$line\n'));
  }

  final Process _process;
  final _pending = <int, Completer<Map<String, Object?>>>{};
  final _stderr = StringBuffer();
  var _nextId = 1;

  static Future<_Server> start(String uri) async {
    final process = await Process.start(
      'dart',
      <String>['run', 'jig_mcp:jig_mcp', '--uri', uri],
      workingDirectory: Directory.current.path,
    );
    return _Server(process);
  }

  String get stderrText => _stderr.toString();

  void _onLine(String line) {
    final Map<String, Object?> message;
    try {
      message = (jsonDecode(line) as Map<Object?, Object?>).cast<String, Object?>();
    } catch (_) {
      // Not a protocol line; a client would ignore it the same way.
      return;
    }
    final id = message['id'];
    if (id is int) {
      _pending.remove(id)?.complete(message);
    }
  }

  Future<Map<String, Object?>> request(
    String method, [
    Map<String, Object?> params = const <String, Object?>{},
    Duration budget = _replyBudget,
  ]) {
    final id = _nextId++;
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    _process.stdin.writeln(
      jsonEncode(<String, Object?>{
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      }),
    );
    return completer.future.timeout(
      budget,
      onTimeout: () {
        _pending.remove(id);
        throw TimeoutException('no reply to $method within ${budget.inSeconds}s');
      },
    );
  }

  Future<Map<String, Object?>> call(
    String tool, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) => request('tools/call', <String, Object?>{
    'name': tool,
    'arguments': arguments,
  });

  Future<int> stop() async {
    await _process.stdin.close();
    return _process.exitCode.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        _process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
  }
}

/// The text of a tool result, when its first content block is text.
String? _textOf(Map<String, Object?> reply) {
  final result = reply['result'];
  if (result is! Map<String, Object?>) {
    return null;
  }
  final content = result['content'];
  if (content is! List<Object?> || content.isEmpty) {
    return null;
  }
  final block = content.first;
  return block is Map<String, Object?> ? block['text'] as String? : null;
}

bool _isError(Map<String, Object?> reply) {
  final result = reply['result'];
  return result is Map<String, Object?> && result['isError'] == true;
}

/// A port nothing is listening on: bind it, read the number, let it go.
Future<int> _closedPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

/// A port that accepts a connection and then says nothing.
///
/// This is the state that made the handshake take 134 seconds: a stale session file
/// naming a host that neither refuses nor answers. A closed port cannot reproduce it,
/// because a refusal is immediate.
Future<ServerSocket> _blackhole() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  socket.listen((Socket client) {
    // Held open, never written to, so the client waits for an upgrade that never
    // arrives - which is exactly what an unreachable VM service looks like.
    client.done.catchError((Object _) {});
  });
  return socket;
}

Future<void> main() async {
  final blackhole = await _blackhole();
  final deadPort = await _closedPort();

  stdout.writeln('== mcp smoke');
  stdout.writeln('  (no app, no device, no session file)');

  final server = await _Server.start('ws://127.0.0.1:${blackhole.port}/ws');

  try {
    // 1. The handshake must not wait for the app. A server that connects first
    // hangs here for the driver's connect timeout, and the editor gives up before
    // the reply: measured at 134s before the fix.
    final watch = Stopwatch()..start();
    final Map<String, Object?> initialize;
    try {
      initialize = await server.request(
        'initialize',
        <String, Object?>{'protocolVersion': '2025-03-26'},
        _handshakeBudget,
      );
      watch.stop();
      final result = initialize['result']! as Map<String, Object?>;
      _pass(
        'initialize answered in ${watch.elapsedMilliseconds}ms with no app '
        '(budget ${_handshakeBudget.inSeconds}s)',
      );
      if (result['instructions'] is String) {
        _pass('initialize carries instructions for the model');
      } else {
        _fail('initialize carries instructions', 'field is ${result['instructions']}');
      }
    } on TimeoutException catch (error) {
      watch.stop();
      _fail(
        'initialize answers without connecting',
        '$error after ${watch.elapsedMilliseconds}ms. The server is waiting on the '
            'app before it speaks, which no client will wait out.\n'
            'stderr: ${server.stderrText}',
      );
      await server.stop();
      await blackhole.close();
      exit(1);
    }

    // 2. The tool list is the surface a model is handed. Advice about cost lives in
    // `instructions`, and a playbook naming a verb the server does not serve is worse
    // than none, so the two are checked against each other.
    final listed = await server.request('tools/list');
    final tools = ((listed['result']! as Map<String, Object?>)['tools']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final names = <String>{for (final tool in tools) tool['name']! as String};
    if (names.length >= 15 && names.containsAll(<String>['connect', 'adjust', 'screenshot'])) {
      _pass('tools/list served ${names.length} tools, including connect/adjust/screenshot');
    } else {
      _fail('tools/list serves the expected surface', 'got ${names.toList()..sort()}');
    }

    final playbook = (initialize['result']! as Map<String, Object?>)['instructions'];
    if (playbook is String) {
      // Only the tool names are checked here. The playbook also names error codes in
      // backticks, and whether those exist is a question about the enum - which the
      // unit test can import and this black-box script deliberately cannot.
      final mentioned = <String>{
        for (final match in RegExp(r'`([a-z][a-zA-Z_]*)`').allMatches(playbook))
          match.group(1)!,
      }.difference(names);
      if (mentioned.isEmpty) {
        _pass('every tool the instructions name is served');
      } else {
        _fail('the instructions name only served tools', 'it names $mentioned');
      }
    }

    // 3. A refused attach is a tool result, not a dead process. The first version of
    // `connect` threw out of the handler, unwound the stdio loop and took the server
    // with it - the one failure a client cannot recover from.
    final refused = await server.call('connect', <String, Object?>{
      'uri': 'ws://127.0.0.1:$deadPort/ws',
    });
    final refusedText = _textOf(refused);
    if (_isError(refused) &&
        refused['error'] == null &&
        refusedText != null &&
        refusedText.contains('NOT_CONNECTED')) {
      _pass('connect to a closed port is an isError result carrying NOT_CONNECTED');
    } else {
      _fail(
        'connect failure is a tool result',
        'reply: ${jsonEncode(refused)}',
      );
    }

    final after = await server.call('ping');
    if (_isError(after) && (after['error'] == null)) {
      _pass('the server still answers after a failed connect');
    } else {
      _fail('the loop survives a failed connect', 'reply: ${jsonEncode(after)}');
    }
  } finally {
    // 4. Closing stdin is the client saying it is done. A server that keeps the
    // isolate alive leaves the editor waiting on a process that never ends.
    final code = await server.stop();
    await blackhole.close();
    if (code == 0) {
      _pass('the server exits 0 when stdin closes');
    } else {
      _fail('the server exits when stdin closes', 'exit code $code');
    }
  }

  if (_failures > 0) {
    stdout.writeln('\n  $_failures check(s) failed.');
    exit(1);
  }
  stdout.writeln('  all checks passed.');
}
