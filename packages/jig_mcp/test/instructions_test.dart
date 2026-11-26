import 'package:jig_driver/jig_driver.dart';
import 'package:jig_mcp/jig_mcp.dart';
import 'package:jig_protocol/jig_protocol.dart';
import 'package:test/test.dart';

/// The initialize response is the only server-level context a client has. A tool
/// description can say what one verb does; nothing except `instructions` can say that
/// one verb is cheaper than another, and a model that does not know that reaches for
/// the most expensive one first.
void main() {
  final server = JigMcpServer(_OfflineVerbs());

  Future<Map<String, Object?>> initialize() async {
    final reply = await server.handle(<String, Object?>{
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'initialize',
      'params': <String, Object?>{'protocolVersion': '2025-03-26'},
    });
    return reply!;
  }

  test('initialize carries instructions', () async {
    final result = (await initialize())['result']! as Map<String, Object?>;

    expect(result['instructions'], isA<String>());
    expect((result['instructions']! as String).length, greaterThan(300));
  });

  test('the instructions rank the tools and say which is dearest', () async {
    final text = JigMcpServer.instructions;

    // The ordering is the point: without it, thirteen descriptions look equal.
    expect(text, contains('Cheapest first'));
    expect(text, contains('`screenshot` - pixels, and the most expensive call'));
  });

  test('the instructions say screenshot is not how to find an element', () async {
    // The exact confusion this exists to prevent: "what is on screen" answered with
    // an image when `tree` already holds the answer, addressed.
    final text = JigMcpServer.instructions;

    expect(text, contains('Do not use it to locate an element'));
    expect(text, contains('that is `tree`'));
  });

  test('every name the instructions mention is a tool or a code that exists', () async {
    // A playbook that mentions a verb the server does not serve is worse than none:
    // the model calls it and gets "not a tool". Backticks keep this honest - only
    // punctuated names are checked, so ordinary prose cannot trip it.
    final tools = <String>{for (final tool in server.tools) tool.name};
    final codes = <String>{for (final code in JigErrorCode.values) code.wire};
    final mentioned = <String>{
      for (final match
          in RegExp(r'`([a-zA-Z_]+)`').allMatches(JigMcpServer.instructions))
        match.group(1)!,
    };

    expect(mentioned, isNotEmpty);
    expect(mentioned.difference(tools).difference(codes), isEmpty);
  });

  test('the instructions name the tool a caller is most likely to reach for wrongly',
      () async {
    final mentioned = <String>{
      for (final match
          in RegExp(r'`([a-zA-Z_]+)`').allMatches(JigMcpServer.instructions))
        match.group(1)!,
    };

    expect(mentioned, containsAll(<String>['tree', 'state', 'events', 'screenshot']));
  });

  test('the instructions name the codes a caller will hit', () async {
    final text = JigMcpServer.instructions;
    final codes = <String>{
      for (final match in RegExp(r'\b(ELEMENT_[A-Z_]+|GESTURE_NO_EFFECT|'
              r'CLEAR_REFUSED|BACK_REFUSED|SCROLL_EXHAUSTED|TIMEOUT)\b')
          .allMatches(text))
        match.group(0)!,
    };

    // Each code quoted in the playbook has to be one the protocol really defines,
    // or the instructions teach an error that cannot happen.
    final known = <String>{for (final code in JigErrorCode.values) code.wire};
    expect(codes.difference(known), isEmpty);
    expect(codes, contains('ELEMENT_NOT_VISIBLE'));
  });
}

final class _OfflineVerbs implements JigVerbs {
  JigResponse get _failure => JigResponse.failure(
    const JigError(JigErrorCode.notConnected, 'offline'),
  );

  @override
  Future<JigResponse> ping() async => _failure;

  @override
  Future<JigResponse> tree({
    bool interactiveOnly = true,
    int limit = 120,
    String? query,
  }) async => _failure;

  @override
  Future<JigResponse> tap(JigSelector selector, {bool long = false}) async =>
      _failure;

  @override
  Future<JigResponse> tapRef(String ref) async => _failure;

  @override
  Future<JigResponse> swipe(
    JigSelector selector, {
    String direction = 'left',
    String? ref,
  }) async => _failure;

  @override
  Future<JigResponse> typeText(JigSelector selector, String value) async =>
      _failure;

  @override
  Future<JigResponse> clear(JigSelector selector) async => _failure;

  @override
  Future<JigResponse> adjust(
    JigSelector selector, {
    String direction = 'up',
    int times = 1,
  }) async => _failure;

  @override
  Future<JigResponse> screenshot({double pixelRatio = 1}) async => _failure;

  @override
  Future<JigResponse> wait(
    JigSelector selector, {
    bool present = true,
    Duration timeout = const Duration(seconds: 10),
  }) async => _failure;

  @override
  Future<JigResponse> scroll(
    JigSelector selector, {
    bool horizontal = false,
    int steps = 20,
    String? within,
  }) async => _failure;

  @override
  Future<JigResponse> state({Iterable<String>? names}) async => _failure;

  @override
  Future<JigResponse> events({
    int since = 0,
    Set<JigSource>? sources,
    int limit = 100,
  }) async => _failure;

  @override
  Future<JigResponse> nav() async => _failure;

  @override
  Future<JigResponse> back() async => _failure;
}
