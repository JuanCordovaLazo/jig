import 'dart:convert';

import 'package:jig_cli/src/scenario.dart';
import 'package:jig_protocol/jig_protocol.dart';
import 'package:test/test.dart';

String _doc(List<Map<String, Object?>> steps) => jsonEncode(<String, Object?>{
  'name': 'demo',
  'steps': steps,
});

void main() {
  group('a scenario it accepts', () {
    test('reads the selector spellings the CLI flags use', () {
      final scenario = JigScenario.parse(
        _doc(<Map<String, Object?>>[
          <String, Object?>{'verb': 'tap', 'key': 'save'},
          <String, Object?>{'verb': 'tap', 'sem': 'Guardar'},
          <String, Object?>{'verb': 'tap', 'type': 'IconButton', 'index': 1},
          <String, Object?>{'verb': 'tap', 'text': 'Enviar'},
          <String, Object?>{'verb': 'tap', 'ref': 'n42'},
        ]),
      );

      expect(scenario.name, 'demo');
      expect(scenario.steps.map((JigScenarioStep s) => s.selector?.kind), <Object?>[
        SelectorKind.key,
        SelectorKind.semantic,
        SelectorKind.widgetType,
        SelectorKind.text,
        null,
      ]);
      expect(scenario.steps[2].selector?.index, 1);
      expect(scenario.steps[4].ref, 'n42');
    });

    test('carries the options a step needs', () {
      final scenario = JigScenario.parse(
        _doc(<Map<String, Object?>>[
          <String, Object?>{'verb': 'wait', 'sem': 'Hecho', 'timeoutMs': 500},
          <String, Object?>{'verb': 'wait', 'sem': 'Hecho', 'present': false},
          <String, Object?>{'verb': 'scroll', 'key': 'row', 'axis': 'horizontal'},
          <String, Object?>{'verb': 'swipe', 'key': 'row', 'direction': 'left'},
          <String, Object?>{
            'verb': 'state',
            'expect': <String, Object?>{'cart.count': 2},
          },
        ]),
      );

      expect(scenario.steps[0].timeout, const Duration(milliseconds: 500));
      expect(scenario.steps[1].present, isFalse);
      expect(scenario.steps[2].horizontal, isTrue);
      expect(scenario.steps[3].direction, 'left');
      expect(scenario.steps[4].expect, <String, Object?>{'cart.count': 2});
    });
  });

  group('a scenario it refuses, by saying what is wrong', () {
    void expectRefused(String source, Matcher message, {int? atStep}) {
      expect(
        () => JigScenario.parse(source),
        throwsA(
          isA<JigScenarioException>()
              .having((JigScenarioException e) => e.message, 'message', message)
              .having((JigScenarioException e) => e.step, 'step', atStep),
        ),
      );
    }

    test('invalid JSON is the caller\'s mistake, not an app failure', () {
      expectRefused('{not json', contains('not valid JSON'));
    });

    test('a missing or empty steps list', () {
      expectRefused('{"name":"x"}', contains('non-empty "steps"'));
      expectRefused('{"steps":[]}', contains('non-empty "steps"'));
    });

    test('an unknown verb names the ones that exist, and where the step is', () {
      expectRefused(
        _doc(<Map<String, Object?>>[
          <String, Object?>{'verb': 'tap', 'key': 'a'},
          <String, Object?>{'verb': 'teleport'},
        ]),
        allOf(contains('"teleport" is not a step verb'), contains('tap')),
        atStep: 1,
      );
    });

    test('eval is not a step, and the refusal says so', () {
      expectRefused(
        _doc(<Map<String, Object?>>[
          <String, Object?>{'verb': 'eval'},
        ]),
        contains('is not a step verb'),
        atStep: 0,
      );
    });

    test('a negative count is refused instead of silently clamped', () {
      expectRefused(
        _doc(<Map<String, Object?>>[
          <String, Object?>{'verb': 'scroll', 'key': 'row', 'steps': -1},
        ]),
        contains('non-negative integer'),
        atStep: 0,
      );
    });

    test('an unknown event source is refused', () {
      expectRefused(
        _doc(<Map<String, Object?>>[
          <String, Object?>{
            'verb': 'events',
            'sources': <String>['nope'],
          },
        ]),
        contains('not an event source'),
        atStep: 0,
      );
    });
  });
}
