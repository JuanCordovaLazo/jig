import 'package:jig_driver/jig_driver.dart';
import 'package:jig_mcp/jig_mcp.dart';
import 'package:jig_protocol/jig_protocol.dart';
import 'package:test/test.dart';

/// The tool list is the whole manual a model gets. It never reads the README, so a
/// terse description or an undocumented argument is not a style problem - it is the
/// agent guessing, which is the failure this project exists to remove.
void main() {
  final server = JigMcpServer(_OfflineVerbs());
  final tools = server.tools;

  test('every tool explains itself in more than a phrase', () {
    final thin = <String>[
      for (final tool in tools)
        if (tool.description.length < 60) '${tool.name}: ${tool.description}',
    ];

    expect(thin, isEmpty);
  });

  test('every argument is documented, including the ones with an enum', () {
    final undocumented = <String>[];
    for (final tool in tools) {
      final properties =
          tool.schema['properties'] as Map<String, Object?>? ?? const <String, Object?>{};
      for (final entry in properties.entries) {
        final spec = entry.value;
        final description = spec is Map<String, Object?> ? spec['description'] : null;
        if (description is! String || description.length < 20) {
          undocumented.add('${tool.name}.${entry.key}');
        }
      }
    }

    expect(undocumented, isEmpty);
  });

  test('a tool that needs a target says one is required, in the one-of form', () {
    // `required` cannot express "one of these", so the constraint is an `anyOf`. A
    // schema that leaves it out invites the client to call with no target at all.
    //
    // Two verbs also take a ref, because the thing they act on may have nothing else
    // to name it - a bare scrollable reports no key, label or type, and a handle from
    // a listing is then the only way to reach it.
    const selectorOnly = <String>['clear', 'adjust', 'wait', 'scroll', 'type'];
    const selectorOrRef = <String>['tap', 'swipe'];

    Set<String> armsOf(String name) {
      final tool = tools.firstWhere((JigTool t) => t.name == name);
      final anyOf = tool.schema['anyOf'] as List<Object?>?;
      expect(anyOf, isNotNull, reason: '$name has no one-of constraint');
      return <String>{
        for (final arm in anyOf!)
          for (final key in (arm as Map<String, Object?>)['required']! as List<Object?>)
            key! as String,
      };
    }

    for (final name in selectorOnly) {
      expect(
        armsOf(name),
        <String>{'key', 'sem', 'text', 'type'},
        reason: '$name should not accept a ref',
      );
    }
    for (final name in selectorOrRef) {
      expect(
        armsOf(name),
        <String>{'key', 'sem', 'text', 'type', 'ref'},
        reason: '$name should accept a ref',
      );
    }
  });

  test('arguments with a closed set of values are enums, not free strings', () {
    Map<String, Object?> propertiesOf(String name) =>
        tools.firstWhere((JigTool t) => t.name == name).schema['properties']!
            as Map<String, Object?>;

    expect(
      (propertiesOf('swipe')['direction']! as Map<String, Object?>)['enum'],
      <String>['left', 'right', 'up', 'down'],
    );
    expect(
      (propertiesOf('scroll')['axis']! as Map<String, Object?>)['enum'],
      <String>['vertical', 'horizontal'],
    );

    final sources =
        (propertiesOf('events')['sources']! as Map<String, Object?>)['items']!
            as Map<String, Object?>;
    expect(sources['enum'], contains('http'));
  });

  test('a mandatory argument is declared, not left to the handler', () {
    final type = tools.firstWhere((JigTool t) => t.name == 'type');

    expect(type.schema['required'], contains('value'));
  });

  test('a failure mode a caller will hit is named in the description', () {
    // Each of these is the error the verb really produces; a model that never read it
    // learns the same fact by burning a call.
    final expected = <String, String>{
      'clear': 'CLEAR_REFUSED',
      'adjust': 'ADJUST_REFUSED',
      'tap': 'ELEMENT_NOT_VISIBLE',
      'swipe': 'GESTURE_NO_EFFECT',
      'type': 'ELEMENT_NOT_EDITABLE',
      'wait': 'TIMEOUT',
      'scroll': 'SCROLL_EXHAUSTED',
      'back': 'BACK_REFUSED',
    };

    for (final entry in expected.entries) {
      final tool = tools.firstWhere((JigTool t) => t.name == entry.key);
      expect(
        tool.description,
        contains(entry.value),
        reason: '${entry.key} never names ${entry.value}',
      );
    }
  });

  test('the screenshot tool says its answer is an image, and it is one', () {
    final shot = tools.firstWhere((JigTool t) => t.name == 'screenshot');

    expect(shot.image, isTrue);
    expect(shot.description, contains('image'));
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
