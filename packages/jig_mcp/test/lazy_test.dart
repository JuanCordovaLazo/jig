import 'dart:async';

import 'package:jig_driver/jig_driver.dart';
import 'package:jig_mcp/jig_mcp.dart';
import 'package:jig_protocol/jig_protocol.dart';
import 'package:test/test.dart';

/// A stale session file pointing at a host that never answers held this server's
/// `initialize` for 134 seconds, so every client gave up and reported a server that
/// never became ready - which says nothing about the real cause. These tests keep
/// the handshake independent of the app.
void main() {
  group('lazy verbs', () {
    test('nothing connects until a verb runs', () async {
      var connects = 0;
      final verbs = JigLazyVerbs(() async {
        connects++;
        return _FakeVerbs();
      });

      expect(connects, 0);
      expect(verbs.isConnected, isFalse);

      await verbs.ping();

      expect(connects, 1);
      expect(verbs.isConnected, isTrue);
    });

    test('a live connection is reused', () async {
      var connects = 0;
      final verbs = JigLazyVerbs(() async {
        connects++;
        return _FakeVerbs();
      });

      await verbs.ping();
      await verbs.nav();
      await verbs.state();

      expect(connects, 1);
    });

    test('a failed connect is not cached, so a relaunched app is picked up', () async {
      var attempts = 0;
      final verbs = JigLazyVerbs(() async {
        attempts++;
        if (attempts == 1) {
          throw const JigConnectionException('nothing there yet');
        }
        return _FakeVerbs();
      });

      final first = await verbs.ping();
      expect(first.error?.code, JigErrorCode.notConnected);
      expect(first.error?.message, contains('nothing there yet'));

      // Same call, second attempt: the app started in between.
      final second = await verbs.ping();
      expect(second.error, isNull);
      expect(attempts, 2);
    });

    test('a connect failure is a NOT_CONNECTED answer, not a thrown error', () async {
      final verbs = JigLazyVerbs(
        () async => throw const JigConnectionException('no app'),
      );

      // The envelope already knows how to say "the app is missing"; a tool error
      // here would tell the client the server broke.
      final response = await verbs.tree();

      expect(response.error?.code, JigErrorCode.notConnected);
    });

    test('reconnect drops the old connection', () async {
      final verbs = JigLazyVerbs(() async => _FakeVerbs(label: 'first'));
      await verbs.ping();

      verbs.reconnect(() async => _FakeVerbs(label: 'second'));
      expect(verbs.isConnected, isFalse);

      final response = await verbs.ping();
      expect(response.data?['label'], 'second');
    });
  });

  group('handshake', () {
    test('initialize answers without touching the transport', () async {
      var connects = 0;
      final verbs = JigLazyVerbs(() async {
        connects++;
        throw const JigConnectionException('slow app');
      });
      final server = JigMcpServer(verbs);

      final reply = await server.handle(<String, Object?>{
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': <String, Object?>{'protocolVersion': '2025-03-26'},
      });

      expect((reply!['result']! as Map<String, Object?>)['instructions'], isNotNull);
      expect(connects, 0, reason: 'initialize must not wait for the app');
    });

    test('tools/list answers without touching the transport', () async {
      var connects = 0;
      final verbs = JigLazyVerbs(() async {
        connects++;
        return _FakeVerbs();
      });
      final server = JigMcpServer(verbs);

      final reply = await server.handle(<String, Object?>{
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'tools/list',
      });

      expect((reply!['result']! as Map<String, Object?>)['tools'], hasLength(15));
      expect(connects, 0);
    });
  });

  group('connect tool', () {
    test('a refused attach is a tool result, so the loop survives', () async {
      final server = JigMcpServer(
        _FakeVerbs(),
        attach: (String uri) async =>
            throw const JigConnectionException('refused'),
      );

      final reply = await server.handle(<String, Object?>{
        'jsonrpc': '2.0',
        'id': 3,
        'method': 'tools/call',
        'params': <String, Object?>{
          'name': 'connect',
          'arguments': <String, Object?>{'uri': 'ws://127.0.0.1:1/ws'},
        },
      });

      final result = reply!['result']! as Map<String, Object?>;
      expect(result['isError'], isTrue);
      expect(
        jsonOf(result),
        allOf(contains('NOT_CONNECTED'), contains('refused')),
      );
    });

    test('an unexpected error stays inside the tool result', () async {
      // Any exception escaping a handler used to kill the stdio loop, which is the
      // one failure a client cannot recover from.
      final server = JigMcpServer(
        _FakeVerbs(throwing: StateError('kaput')),
      );

      final reply = await server.handle(<String, Object?>{
        'jsonrpc': '2.0',
        'id': 4,
        'method': 'tools/call',
        'params': <String, Object?>{'name': 'ping', 'arguments': <String, Object?>{}},
      });

      final result = reply!['result']! as Map<String, Object?>;
      expect(result['isError'], isTrue);
      expect(jsonOf(result), contains('INTERNAL'));
      expect(reply['error'], isNull);
    });

    test('connect without a uri is a bad argument', () async {
      final server = JigMcpServer(_FakeVerbs());

      final reply = await server.handle(<String, Object?>{
        'jsonrpc': '2.0',
        'id': 5,
        'method': 'tools/call',
        'params': <String, Object?>{
          'name': 'connect',
          'arguments': <String, Object?>{},
        },
      });

      expect((reply!['error']! as Map<String, Object?>)['code'],
          JigRpcCode.invalidParams);
    });
  });
}

String jsonOf(Map<String, Object?> result) {
  final content = result['content']! as List<Object?>;
  return (content.first! as Map<String, Object?>)['text']! as String;
}

final class _FakeVerbs implements JigVerbs {
  _FakeVerbs({this.label = 'fake', this.throwing});

  final String label;
  final Object? throwing;

  JigResponse get _ok => JigResponse.ok(<String, Object?>{'label': label});

  JigResponse _check() {
    final error = throwing;
    if (error != null) {
      throw error;
    }
    return _ok;
  }

  @override
  Future<JigResponse> ping() async => _check();

  @override
  Future<JigResponse> tree({
    bool interactiveOnly = true,
    int limit = 120,
    String? query,
  }) async => _check();

  @override
  Future<JigResponse> tap(JigSelector selector, {bool long = false}) async =>
      _check();

  @override
  Future<JigResponse> tapRef(String ref) async => _check();

  @override
  Future<JigResponse> swipe(
    JigSelector selector, {
    String direction = 'left',
    String? ref,
  }) async => _check();

  @override
  Future<JigResponse> typeText(JigSelector selector, String value) async =>
      _check();

  @override
  Future<JigResponse> clear(JigSelector selector) async => _check();

  @override
  Future<JigResponse> adjust(
    JigSelector selector, {
    String direction = 'up',
    int times = 1,
  }) async => _check();

  @override
  Future<JigResponse> screenshot({double pixelRatio = 1}) async => _check();

  @override
  Future<JigResponse> wait(
    JigSelector selector, {
    bool present = true,
    Duration timeout = const Duration(seconds: 10),
  }) async => _check();

  @override
  Future<JigResponse> scroll(
    JigSelector selector, {
    bool horizontal = false,
    int steps = 20,
    String? within,
  }) async => _check();

  @override
  Future<JigResponse> state({Iterable<String>? names}) async => _check();

  @override
  Future<JigResponse> events({
    int since = 0,
    Set<JigSource>? sources,
    int limit = 100,
  }) async => _check();

  @override
  Future<JigResponse> nav() async => _check();

  @override
  Future<JigResponse> back() async => _check();
}
