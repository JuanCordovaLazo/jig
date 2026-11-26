import 'dart:convert';

import 'package:jig_cli/src/runner.dart';
import 'package:jig_cli/src/scenario.dart';
import 'package:jig_driver/jig_driver.dart';
import 'package:jig_protocol/jig_protocol.dart';
import 'package:test/test.dart';

/// A driver that answers from a script, so the runner's success path can be tested
/// without a device. Each verb records that it was called.
final class _FakeVerbs implements JigVerbs {
  _FakeVerbs({
    this.stateValues = const <String, Object?>{},
    this.failOnTap,
  });

  final Map<String, Object?> stateValues;

  /// When set, `tap` answers with this error instead of succeeding.
  final JigError? failOnTap;

  final List<String> calls = <String>[];

  @override
  Future<JigResponse> ping() async {
    calls.add('ping');
    return const JigResponse.ok(<String, Object?>{
      'protocol': jigProtocolVersion,
    });
  }

  @override
  Future<JigResponse> tap(JigSelector selector, {bool long = false}) async {
    calls.add('tap:${selector.describe()}');
    final error = failOnTap;
    if (error != null) {
      return JigResponse.failure(error);
    }
    return JigResponse.ok(<String, Object?>{'action': 'tap'});
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
    return const JigResponse.ok(<String, Object?>{'format': 'png'});
  }

  @override
  Future<JigResponse> swipe(
    JigSelector selector, {
    String direction = 'left',
    String? ref,
  }) async {
    calls.add('swipe:${selector.describe()}:$direction');
    return JigResponse.ok(<String, Object?>{'gesture': 'swipe'});
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
    calls.add('scroll:${selector.describe()}:$horizontal');
    return const JigResponse.ok(<String, Object?>{});
  }

  @override
  Future<JigResponse> state({Iterable<String>? names}) async {
    final selected = names ?? stateValues.keys;
    calls.add('state:${selected.join(',')}');
    // Mirrors the wire shape the app really sends: a list of entries, not a map.
    return JigResponse.ok(<String, Object?>{
      'count': selected.length,
      'values': <Map<String, Object?>>[
        for (final name in selected)
          // A registered reader reports `value`; an unknown name reports `error`,
          // which is exactly what JigStateRegistry.snapshot does.
          stateValues.containsKey(name)
              ? <String, Object?>{'name': name, 'value': stateValues[name]}
              : <String, Object?>{'name': name, 'error': 'not registered'},
      ],
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
    return JigResponse.ok(<String, Object?>{'count': 0});
  }
}

JigScenario _scenario(List<Map<String, Object?>> steps) => JigScenario.parse(
  jsonEncode(<String, Object?>{'name': 'checkout', 'steps': steps}),
);

void main() {
  test('a state step reads the values list the app actually sends', () async {
    // The wire shape is `{count, values: [{name, value}]}`. Reading it as a map made
    // a registered value look missing the first time this ran on a device, so the
    // fake mirrors the real payload rather than the shape the runner wished for.
    final verbs = _FakeVerbs(stateValues: <String, Object?>{'route': '/cart'});
    final report = await JigRunner.run(
      verbs,
      _scenario(<Map<String, Object?>>[
        <String, Object?>{
          'verb': 'state',
          'expect': <String, Object?>{'route': '/cart'},
        },
      ]),
    );

    expect(report.ok, isTrue);
  });

  test('a name that is not registered fails the step by name', () async {
    final verbs = _FakeVerbs(stateValues: <String, Object?>{'route': '/cart'});
    final report = await JigRunner.run(
      verbs,
      _scenario(<Map<String, Object?>>[
        <String, Object?>{
          'verb': 'state',
          'expect': <String, Object?>{'missing.thing': 1},
        },
      ]),
    );

    expect(report.ok, isFalse);
    expect(
      report.steps.single.error?.message,
      contains('missing.thing could not be read: not registered'),
    );
  });
  test('a scenario that passes runs every step in order', () async {
    final verbs = _FakeVerbs(
      stateValues: <String, Object?>{'cart.count': 2},
    );
    final report = await JigRunner.run(
      verbs,
      _scenario(<Map<String, Object?>>[
        <String, Object?>{'verb': 'ping'},
        <String, Object?>{'verb': 'tap', 'key': 'add_to_cart'},
        <String, Object?>{
          'verb': 'state',
          'expect': <String, Object?>{'cart.count': 2},
        },
        <String, Object?>{'verb': 'nav'},
      ]),
    );

    expect(report.ok, isTrue);
    expect(report.passed, 4);
    expect(report.skipped, 0);
    expect(report.stoppedAt, isNull);
    expect(verbs.calls, <String>[
      'ping',
      "tap:key 'add_to_cart'",
      'state:cart.count',
      'nav',
    ]);

    final json = report.toJson();
    expect(json['failed'], 0);
    expect((json['steps']! as List<Object?>), hasLength(4));
  });

  test('a failure stops the run and the rest is reported as skipped', () async {
    final verbs = _FakeVerbs(
      failOnTap: const JigError(
        JigErrorCode.elementNotFound,
        'Nothing matches key \'missing\'',
      ),
    );
    final report = await JigRunner.run(
      verbs,
      _scenario(<Map<String, Object?>>[
        <String, Object?>{'verb': 'ping'},
        <String, Object?>{'verb': 'tap', 'key': 'missing'},
        <String, Object?>{'verb': 'nav'},
      ]),
    );

    expect(report.ok, isFalse);
    expect(report.stoppedAt, 1);
    expect(report.steps[1].status, 'failed');
    expect(report.steps[1].error?.code, JigErrorCode.elementNotFound);

    // Skipped, not omitted: a report that just ends early reads like a shorter
    // scenario, and the caller cannot tell which it is.
    expect(report.steps[2].status, 'skipped');
    expect(report.skipped, 1);
    expect(report.toJson()['failed'], 1);

    // The step after the failure must not have run.
    expect(verbs.calls, isNot(contains('nav')));
  });

  test('an expectation mismatch is its own code, with the actual value', () async {
    final verbs = _FakeVerbs(stateValues: <String, Object?>{'cart.count': 1});
    final report = await JigRunner.run(
      verbs,
      _scenario(<Map<String, Object?>>[
        <String, Object?>{
          'verb': 'state',
          'expect': <String, Object?>{'cart.count': 2},
        },
      ]),
    );

    expect(report.ok, isFalse);
    final error = report.steps.single.error;
    // Not INTERNAL and not TIMEOUT: the app answered, with a different number.
    expect(error?.code, JigErrorCode.expectationFailed);
    expect(error?.message, contains('cart.count was 1, expected 2'));
    expect(error?.candidates, contains('cart.count=1'));
  });

  test('a step missing what it needs fails as a bad scenario', () async {
    final verbs = _FakeVerbs();
    final report = await JigRunner.run(
      verbs,
      _scenario(<Map<String, Object?>>[
        <String, Object?>{'verb': 'swipe', 'key': 'row'},
      ]),
    );

    expect(report.ok, isFalse);
    expect(report.steps.single.error?.code, JigErrorCode.invalidSelector);
    expect(report.steps.single.error?.message, contains('needs "direction"'));
  });

  test('a tap step with no selector is refused before it reaches the app', () async {
    final verbs = _FakeVerbs();
    final report = await JigRunner.run(
      verbs,
      _scenario(<Map<String, Object?>>[
        <String, Object?>{'verb': 'tap'},
      ]),
    );

    expect(report.steps.single.error?.code, JigErrorCode.invalidSelector);
    expect(verbs.calls, isEmpty);
  });

  test('a clear step reaches the verb that reads the field back', () async {
    final verbs = _FakeVerbs();
    final report = await JigRunner.run(
      verbs,
      _scenario(<Map<String, Object?>>[
        <String, Object?>{'verb': 'clear', 'key': 'name_field'},
      ]),
    );

    expect(report.ok, isTrue);
    expect(verbs.calls, <String>["clear:key 'name_field'"]);
  });

  test('an adjust step carries its direction and step count', () async {
    final verbs = _FakeVerbs();
    final report = await JigRunner.run(
      verbs,
      _scenario(<Map<String, Object?>>[
        <String, Object?>{
          'verb': 'adjust',
          'key': 'rating_slider',
          'direction': 'down',
          'times': 2,
        },
      ]),
    );

    expect(report.ok, isTrue);
    expect(verbs.calls, <String>["adjust:key 'rating_slider':down*2"]);
  });

  test('an adjust step defaults to one step up', () async {
    final verbs = _FakeVerbs();
    await JigRunner.run(
      verbs,
      _scenario(<Map<String, Object?>>[
        <String, Object?>{'verb': 'adjust', 'key': 'rating_slider'},
      ]),
    );

    expect(verbs.calls, <String>["adjust:key 'rating_slider':up*1"]);
  });

  test('a type step with an empty value is refused, pointing at clear', () async {
    final verbs = _FakeVerbs();
    final report = await JigRunner.run(
      verbs,
      _scenario(<Map<String, Object?>>[
        <String, Object?>{'verb': 'type', 'key': 'name_field', 'value': ''},
      ]),
    );

    // An empty value would replay as typing nothing while reporting success, which
    // is exactly the claim the clear verb exists to make checkable.
    expect(report.steps.single.error?.message, contains('clear'));
    expect(verbs.calls, isEmpty);
  });
}
