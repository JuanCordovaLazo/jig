import 'dart:convert';

import 'package:jig_driver/jig_driver.dart';
import 'package:jig_mcp/jig_mcp.dart';
import 'package:jig_protocol/jig_protocol.dart';
import 'package:test/test.dart';

/// A driver that answers from a script, so the protocol layer is tested without a
/// socket or an app.
final class _FakeVerbs implements JigVerbs {
  _FakeVerbs({this.tapError});

  final JigError? tapError;
  final List<String> calls = <String>[];

  @override
  Future<JigResponse> ping() async {
    calls.add('ping');
    return const JigResponse.ok(<String, Object?>{'protocol': '0.1'});
  }

  @override
  Future<JigResponse> tap(JigSelector selector, {bool long = false}) async {
    calls.add('tap:${selector.describe()}');
    final error = tapError;
    return error == null
        ? JigResponse.ok(<String, Object?>{'action': 'tap'})
        : JigResponse.failure(error);
  }

  @override
  Future<JigResponse> tapRef(String ref) async {
    calls.add('tapRef:$ref');
    return JigResponse.ok(<String, Object?>{'ref': ref});
  }

  @override
  Future<JigResponse> typeText(JigSelector selector, String value) async {
    calls.add('type:${selector.describe()}=$value');
    return JigResponse.ok(<String, Object?>{'text': value});
  }

  @override
  Future<JigResponse> clear(JigSelector selector) async {
    calls.add('clear:${selector.describe()}');
    return const JigResponse.ok(<String, Object?>{'text': ''});
  }

  @override
  Future<JigResponse> adjust(
    JigSelector selector, {
    String direction = 'up',
    int times = 1,
  }) async {
    calls.add('adjust:${selector.describe()}:$direction*$times');
    return const JigResponse.ok(<String, Object?>{'value': '80%'});
  }

  @override
  Future<JigResponse> screenshot({double pixelRatio = 1}) async {
    calls.add('screenshot:$pixelRatio');
    return JigResponse.ok(<String, Object?>{
      'format': 'png',
      'width': 4,
      'height': 3,
      'bytes': 3,
      'pixelRatio': pixelRatio,
      // A 1x1 PNG is enough to prove the bytes survive the protocol layer.
      'base64': _onePixelPng,
    });
  }

  @override
  Future<JigResponse> swipe(
    JigSelector selector, {
    String direction = 'left',
    String? ref,
  }) async {
    calls.add('swipe:${selector.describe()}:$direction');
    return const JigResponse.ok(<String, Object?>{'gesture': 'swipe'});
  }

  @override
  Future<JigResponse> wait(
    JigSelector selector, {
    bool present = true,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    calls.add('wait:${selector.describe()}:$present');
    return const JigResponse.ok(<String, Object?>{});
  }

  @override
  Future<JigResponse> scroll(
    JigSelector selector, {
    bool horizontal = false,
    int steps = 20,
    String? within,
  }) async {
    calls.add('scroll:${selector.describe()}:$horizontal:$within');
    return const JigResponse.ok(<String, Object?>{});
  }

  @override
  Future<JigResponse> state({Iterable<String>? names}) async {
    calls.add('state:${names?.join(',') ?? ''}');
    return const JigResponse.ok(<String, Object?>{
      'state': <String, Object?>{},
    });
  }

  @override
  Future<JigResponse> events({
    int since = 0,
    Set<JigSource>? sources,
    int limit = 100,
  }) async {
    calls.add('events:$since');
    return const JigResponse.ok(<String, Object?>{'events': <Object?>[]});
  }

  @override
  Future<JigResponse> nav() async {
    calls.add('nav');
    return const JigResponse.ok(<String, Object?>{});
  }

  @override
  Future<JigResponse> back() async {
    calls.add('back');
    return const JigResponse.ok(<String, Object?>{'popped': true});
  }

  @override
  Future<JigResponse> tree({
    bool interactiveOnly = true,
    int limit = 120,
    String? query,
  }) async {
    calls.add('tree');
    return const JigResponse.ok(<String, Object?>{'count': 0});
  }
}

Future<Map<String, Object?>> _call(
  JigMcpServer server,
  String tool,
  Map<String, Object?> arguments,
) async {
  final reply = await server.handle(<String, Object?>{
    'jsonrpc': '2.0',
    'id': 7,
    'method': 'tools/call',
    'params': <String, Object?>{'name': tool, 'arguments': arguments},
  });
  return reply!;
}

String _contentText(Map<String, Object?> reply) {
  final result = reply['result']! as Map<String, Object?>;
  final content = result['content']! as List<Object?>;
  return (content.single! as Map<String, Object?>)['text']! as String;
}

bool _isError(Map<String, Object?> reply) =>
    (reply['result']! as Map<String, Object?>)['isError']! as bool;

void main() {
  group('framing', () {
    test('parses a request and tells a notification from a call', () {
      final request = JigRpcMessage.parse(
        '{"jsonrpc":"2.0","id":3,"method":"tools/list"}',
      );
      expect(request?.id, 3);
      expect(request?.method, 'tools/list');
      expect(request?.isNotification, isFalse);

      final notification = JigRpcMessage.parse(
        '{"jsonrpc":"2.0","method":"notifications/initialized"}',
      );
      expect(notification?.isNotification, isTrue);
    });

    test('a line it cannot answer is null, not an exception', () {
      // A malformed line must not kill the server: the client may be streaming
      // diagnostics on the same channel.
      expect(JigRpcMessage.parse(''), isNull);
      expect(JigRpcMessage.parse('not json'), isNull);
      expect(JigRpcMessage.parse('"a string"'), isNull);
      expect(JigRpcMessage.parse('{"id":1}'), isNull);
    });

    test('a reply carries the id it answers', () {
      expect(
        JigRpcMessage.result(9, <String, Object?>{'ok': true}),
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': 9,
          'result': <String, Object?>{'ok': true},
        },
      );
      final failure = JigRpcMessage.error(9, JigRpcCode.invalidParams, 'bad');
      expect((failure['error']! as Map<String, Object?>)['code'], -32602);
    });
  });

  group('handshake', () {
    test('initialize echoes a version this server has been tested against', () async {
      final server = JigMcpServer(_FakeVerbs());
      final reply = await server.handle(<String, Object?>{
        'id': 1,
        'method': 'initialize',
        'params': <String, Object?>{'protocolVersion': '2025-03-26'},
      });

      final result = reply!['result']! as Map<String, Object?>;
      expect(result['protocolVersion'], '2025-03-26');
      expect(result['serverInfo'], isA<Map<String, Object?>>());
      expect(result['capabilities'], isA<Map<String, Object?>>());
    });

    test('initialize advertises our version rather than claiming an unknown one', () async {
      final server = JigMcpServer(_FakeVerbs());
      final reply = await server.handle(<String, Object?>{
        'id': 1,
        'method': 'initialize',
        'params': <String, Object?>{'protocolVersion': '9000-01-01'},
      });

      // Echoing a version we have never run would be a claim, not a handshake.
      final result = reply!['result']! as Map<String, Object?>;
      expect(result['protocolVersion'], '2024-11-05');
    });

    test('a notification is never answered', () async {
      final server = JigMcpServer(_FakeVerbs());
      expect(
        await server.handle(<String, Object?>{
          'method': 'notifications/initialized',
        }),
        isNull,
      );
    });

    test('an unknown method is a protocol error', () async {
      final server = JigMcpServer(_FakeVerbs());
      final reply = await server.handle(<String, Object?>{
        'id': 5,
        'method': 'resources/list',
      });
      expect(
        (reply!['error']! as Map<String, Object?>)['code'],
        JigRpcCode.methodNotFound,
      );
    });
  });

  group('tools', () {
    test('every verb the server serves is listed with a schema', () async {
      final server = JigMcpServer(_FakeVerbs());
      final reply = await server.handle(<String, Object?>{
        'id': 1,
        'method': 'tools/list',
      });

      final tools = ((reply!['result']! as Map<String, Object?>)['tools']!
              as List<Object?>)
          .cast<Map<String, Object?>>();
      final names = tools.map((Map<String, Object?> t) => t['name']).toList();

      expect(names, containsAll(<String>[
        'ping',
        'tree',
        'tap',
        'swipe',
        'type',
        'wait',
        'scroll',
        'state',
        'events',
        'nav',
        'back',
      ]));
      // A tool without a schema is a tool a client cannot call.
      for (final tool in tools) {
        expect(tool['inputSchema'], isA<Map<String, Object?>>());
        expect(tool['description'], isNotEmpty);
      }
    });

    test('a call reaches the verb with the arguments it was given', () async {
      final verbs = _FakeVerbs();
      final server = JigMcpServer(verbs);

      final reply = await _call(server, 'swipe', <String, Object?>{
        'key': 'row',
        'direction': 'up',
      });

      expect(_isError(reply), isFalse);
      expect(verbs.calls, <String>["swipe:key 'row':up"]);
      expect(jsonDecode(_contentText(reply)), containsPair('gesture', 'swipe'));
    });

    test('tap accepts a ref as well as a selector', () async {
      final verbs = _FakeVerbs();
      final server = JigMcpServer(verbs);

      await _call(server, 'tap', <String, Object?>{'ref': 'n42'});
      expect(verbs.calls, <String>['tapRef:n42']);
    });

    test('an app failure is a tool error carrying the jig code, not a success', () async {
      final server = JigMcpServer(
        _FakeVerbs(
          tapError: const JigError(
            JigErrorCode.elementNotVisible,
            'key \'x\' is behind a modal',
          ),
        ),
      );

      final reply = await _call(server, 'tap', <String, Object?>{'key': 'x'});

      // The tool ran and the thing failed. Saying "ok" here would be the same lie as
      // a CLI that exits 0 on a failed tap.
      expect(_isError(reply), isTrue);
      final payload = jsonDecode(_contentText(reply)) as Map<String, Object?>;
      expect(payload['code'], 'ELEMENT_NOT_VISIBLE');
      expect(payload['message'], contains('behind a modal'));
    });

    test('an unknown tool names the ones that exist', () async {
      final server = JigMcpServer(_FakeVerbs());
      final reply = await _call(server, 'teleport', const <String, Object?>{});

      final error = reply['error']! as Map<String, Object?>;
      expect(error['code'], JigRpcCode.invalidParams);
      expect(error['message'], contains('"teleport" is not a tool'));
      expect(error['message'], contains('ping'));
    });

    test('a call with no usable selector is an invalid request, not a tool error', () async {
      final verbs = _FakeVerbs();
      final server = JigMcpServer(verbs);

      final reply = await _call(server, 'tap', const <String, Object?>{});

      // The tool never ran, so this is the client's mistake: a JSON-RPC error, not a
      // result saying the app failed.
      expect(reply.containsKey('error'), isTrue);
      expect((reply['error']! as Map<String, Object?>)['code'], JigRpcCode.invalidParams);
      expect(verbs.calls, isEmpty);
    });

    test('clear empties a field through the type extension', () async {
      final verbs = _FakeVerbs();
      final server = JigMcpServer(verbs);

      final reply = await _call(server, 'clear', <String, Object?>{
        'key': 'name_field',
      });

      expect(_isError(reply), isFalse);
      expect(verbs.calls, <String>["clear:key 'name_field'"]);
    });

    test('type refuses to empty a field, so clear is the only spelling', () async {
      final verbs = _FakeVerbs();
      final server = JigMcpServer(verbs);

      final reply = await _call(server, 'type', <String, Object?>{
        'key': 'x',
        'value': '',
      });

      final error = reply['error']! as Map<String, Object?>;
      expect(error['code'], JigRpcCode.invalidParams);
      expect(error['message'], contains('clear'));
      expect(verbs.calls, isEmpty);
    });

    test('screenshot answers with an image block, not a path', () async {
      final verbs = _FakeVerbs();
      final server = JigMcpServer(verbs);

      final reply = await _call(server, 'screenshot', <String, Object?>{
        'pixelRatio': 2,
      });

      final result = reply['result']! as Map<String, Object?>;
      expect(result['isError'], isFalse);
      final content = (result['content']! as List<Object?>)
          .cast<Map<String, Object?>>();

      final image = content.first;
      expect(image['type'], 'image');
      expect(image['mimeType'], 'image/png');
      // The bytes are what the client renders, so they have to arrive intact.
      expect(
        base64Decode(image['data']! as String).take(8).toList(),
        <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
      );

      // Dimensions travel as their own text block: a caller quotes those, not pixels.
      final facts =
          jsonDecode(content.last['text']! as String) as Map<String, Object?>;
      expect(facts['width'], 4);
      expect(facts['pixelRatio'], 2);
      expect(facts.containsKey('base64'), isFalse);
      expect(verbs.calls, <String>['screenshot:2.0']);
    });
  });
}

/// A 1x1 PNG, so the protocol layer can be tested without a device.
const String _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMB'
    'AQDJ/pLvAAAAAElFTkSuQmCC';
