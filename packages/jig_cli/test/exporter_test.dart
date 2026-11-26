import 'dart:convert';

import 'package:jig_cli/src/exporter.dart';
import 'package:jig_cli/src/scenario.dart';
import 'package:test/test.dart';

JigScenario _scenario(List<Map<String, Object?>> steps) => JigScenario.parse(
  jsonEncode(<String, Object?>{'name': 'flow', 'steps': steps}),
);

String _export(List<Map<String, Object?>> steps) =>
    JigExporter.export(_scenario(steps), entry: 'package:app/main.dart');

void main() {
  group('the emitted file', () {
    test('is self-contained: it carries its own frame helpers', () {
      final source = _export(<Map<String, Object?>>[
        <String, Object?>{'verb': 'tap', 'key': 'save'},
      ]);

      // Regenerating into another project must not need this repository's test
      // support package, so both helpers travel inside the file.
      expect(source, contains('Future<T> _drive<T>('));
      expect(source, contains('Future<void> _pumpUntil('));
      expect(source, contains("import 'dart:async';"));
      expect(source, contains("import 'package:app/main.dart' as app;"));
      expect(source, contains('await app.main();'));
      expect(source, contains('handle.dispose();'));
    });

    test('the generated test owns the runtime lifecycle', () {
      final source = _export(<Map<String, Object?>>[
        <String, Object?>{'verb': 'tap', 'key': 'save'},
      ]);

      // `app.main()` installs a semantics handle and registers extensions; leaving
      // them behind fails the run with "A SemanticsHandle was active at the end of
      // the test". Found by running a generated test on an emulator.
      expect(source, contains('Jig.uninstall();'));
      expect(source, contains('handle.dispose();'));
    });

    test('calls the verbs, not WidgetTester finders', () {
      final source = _export(<Map<String, Object?>>[
        <String, Object?>{'verb': 'tap', 'key': 'save'},
      ]);

      // A generated `tester.tap(find.byKey(...))` would be a second harness with
      // different semantics; the point is to reuse the one that is checked.
      expect(source, contains("JigActions.tap(JigSelector.key('save'))"));
      expect(source, isNot(contains('find.byKey')));
    });

    test('renders every selector spelling the scenario allows', () {
      final source = _export(<Map<String, Object?>>[
        <String, Object?>{'verb': 'tap', 'key': 'k'},
        <String, Object?>{'verb': 'tap', 'sem': 'Guardar', 'exact': false},
        <String, Object?>{'verb': 'tap', 'type': 'IconButton', 'index': 2},
        <String, Object?>{'verb': 'tap', 'text': 'Enviar'},
      ]);

      expect(source, contains("JigSelector.key('k')"));
      expect(source, contains("JigSelector.semantic('Guardar', exact: false)"));
      expect(source, contains("JigSelector.widgetType('IconButton', index: 2)"));
      expect(source, contains("JigSelector.text('Enviar')"));
    });

    test('a clear step exports the verb that proves itself, not an empty type', () {
      final source = _export(<Map<String, Object?>>[
        <String, Object?>{'verb': 'clear', 'sem': 'Nombre'},
      ]);

      expect(source, contains("JigActions.clearText(JigSelector.semantic("));
      expect(source, isNot(contains('JigActions.typeText(')));
    });

    test('an adjust step exports the verb, with its direction and count', () {
      final source = _export(<Map<String, Object?>>[
        <String, Object?>{
          'verb': 'adjust',
          'key': 'rating_slider',
          'direction': 'down',
          'times': 2,
        },
      ]);

      expect(source, contains("JigActions.adjust("));
      expect(source, contains('increase: false'));
      expect(source, contains('times: 2'));
    });

    test('turns an assertion into an expect on the registered reader', () {
      final source = _export(<Map<String, Object?>>[
        <String, Object?>{
          'verb': 'state',
          'expect': <String, Object?>{'cart.count': 2, 'cart.ready': true},
        },
      ]);

      expect(source, contains("only: <String>['cart.count', 'cart.ready']"));
      expect(source, contains("expect(snapshot['cart.count']?.value, 2);"));
      expect(source, contains("expect(snapshot['cart.ready']?.value, true);"));
    });

    test('a string expectation travels as a Dart string literal', () {
      final source = _export(<Map<String, Object?>>[
        <String, Object?>{
          'verb': 'state',
          'expect': <String, Object?>{'route': "/it's"},
        },
      ]);

      // An unescaped quote here would generate a file that does not compile.
      expect(source, contains(r"'/it\'s'"));
    });

    test('wait becomes a frame budget rather than a clock', () {
      final source = _export(<Map<String, Object?>>[
        <String, Object?>{'verb': 'wait', 'sem': 'Hecho', 'timeoutMs': 1600},
      ]);

      // 1600 ms / 16 ms per frame, so a hung app fails instead of hanging CI.
      expect(source, contains('maxFrames: 100'));
      expect(source, contains("() => JigActions.isPresent(JigSelector.semantic('Hecho'"));
    });

    test('an absent wait inverts the predicate', () {
      final source = _export(<Map<String, Object?>>[
        <String, Object?>{'verb': 'wait', 'sem': 'Hecho', 'present': false},
      ]);

      expect(source, contains('() => !(JigActions.isPresent('));
    });
  });

  group('what it refuses', () {
    test('a step with no in-process equivalent stops the export, by name', () {
      final scenario = _scenario(<Map<String, Object?>>[
        <String, Object?>{'verb': 'tap', 'key': 'save'},
        <String, Object?>{'verb': 'events'},
      ]);

      expect(
        () => JigExporter.export(scenario, entry: 'package:app/main.dart'),
        throwsA(
          isA<JigExportException>()
              .having((JigExportException e) => e.steps, 'steps', <int>[2])
              .having(
                (JigExportException e) => e.message,
                'message',
                allOf(contains('step 2 uses events'), contains('jig run')),
              ),
        ),
      );
      expect(JigExporter.unsupportedSteps(scenario), <int>[2]);
    });

    test('several diagnostics are listed together, and pluralised correctly', () {
      final scenario = _scenario(<Map<String, Object?>>[
        <String, Object?>{'verb': 'ping'},
        <String, Object?>{'verb': 'tree'},
        <String, Object?>{'verb': 'tap', 'key': 'save'},
      ]);

      expect(JigExporter.unsupportedSteps(scenario), <int>[1, 2]);
      expect(
        () => JigExporter.export(scenario, entry: 'package:app/main.dart'),
        throwsA(
          isA<JigExportException>().having(
            (JigExportException e) => e.message,
            'message',
            contains('steps 1, 2 use ping, tree'),
          ),
        ),
      );
    });

    test('a fully acting scenario is exported without complaint', () {
      expect(
        JigExporter.unsupportedSteps(
          _scenario(<Map<String, Object?>>[
            <String, Object?>{'verb': 'type', 'sem': 'Nombre', 'value': 'Ana'},
            <String, Object?>{'verb': 'tap', 'key': 'submit'},
            <String, Object?>{'verb': 'back'},
          ]),
        ),
        isEmpty,
      );
    });
  });
}
