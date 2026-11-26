import 'dart:convert';

import 'package:jig_cli/src/recorder.dart';
import 'package:jig_cli/src/scenario.dart';
import 'package:jig_protocol/jig_protocol.dart';
import 'package:test/test.dart';

JigEvent _verbEvent(
  String kind,
  Map<String, Object?> data, {
  int seq = 1,
}) => JigEvent(
  seq: seq,
  source: JigSource.custom,
  kind: kind,
  atMs: 0,
  data: data,
);

Map<String, Object?> _spec(SelectorKind kind, String value, {int? index}) =>
    <String, Object?>{
      'kind': kind.name,
      'value': value,
      'index': ?index,
    };

void main() {
  test('records a runnable scenario from the events the app emitted', () {
    final recording = JigRecorder.record(
      <JigEvent>[
        _verbEvent('tap', <String, Object?>{
          'selector': "key 'add'",
          'selectorSpec': _spec(SelectorKind.key, 'add'),
        }, seq: 1),
        _verbEvent('type', <String, Object?>{
          'selector': "label 'Nombre'",
          'selectorSpec': _spec(SelectorKind.semantic, 'Nombre'),
          'text': 'Ana',
        }, seq: 2),
        _verbEvent('swipe', <String, Object?>{
          'selectorSpec': _spec(SelectorKind.key, 'row'),
          'direction': 'left',
        }, seq: 3),
        _verbEvent('scroll', <String, Object?>{
          'selectorSpec': _spec(SelectorKind.widgetType, 'ListView', index: 1),
          'steps': 4,
        }, seq: 4),
        _verbEvent('clear', <String, Object?>{
          'selector': "key 'email'",
          'selectorSpec': _spec(SelectorKind.key, 'email'),
        }, seq: 5),
        _verbEvent('adjust', <String, Object?>{
          'selector': "key 'rating_slider'",
          'selectorSpec': _spec(SelectorKind.key, 'rating_slider'),
          'direction': 'down',
          'times': 2,
        }, seq: 6),
      ],
      name: 'checkout',
    );

    expect(recording.skippedEvents, 0);
    expect(recording.toJson(), <String, Object?>{
      'name': 'checkout',
      'steps': <Map<String, Object?>>[
        <String, Object?>{'verb': 'tap', 'key': 'add'},
        <String, Object?>{'verb': 'type', 'sem': 'Nombre', 'value': 'Ana'},
        <String, Object?>{'verb': 'swipe', 'key': 'row', 'direction': 'left'},
        <String, Object?>{
          'verb': 'scroll',
          'type': 'ListView',
          'index': 1,
          'steps': 4,
        },
        <String, Object?>{'verb': 'clear', 'key': 'email'},
        <String, Object?>{
          'verb': 'adjust',
          'key': 'rating_slider',
          'direction': 'down',
          'times': 2,
        },
      ],
    });
  });

  test('what it records can be parsed back by the runner', () {
    // The only property that matters: a recording is a scenario, not a lookalike.
    final recording = JigRecorder.record(
      <JigEvent>[
        _verbEvent('tap', <String, Object?>{
          'selectorSpec': _spec(SelectorKind.key, 'save'),
        }),
        _verbEvent('type', <String, Object?>{
          'selectorSpec': _spec(SelectorKind.semantic, 'Nombre'),
          'text': 'Ana',
        }, seq: 2),
        _verbEvent('swipe', <String, Object?>{
          'selectorSpec': _spec(SelectorKind.key, 'row'),
          'direction': 'up',
        }, seq: 3),
      ],
      name: 'roundtrip',
    );

    final parsed = JigScenario.parse(jsonEncode(recording.toJson()));

    expect(parsed.name, 'roundtrip');
    expect(parsed.steps.map((JigScenarioStep s) => s.verb), <String>[
      'tap',
      'type',
      'swipe',
    ]);
    expect(parsed.steps[1].value, 'Ana');
    expect(parsed.steps[2].direction, 'up');
  });

  test('an event with no structured selector is counted, not guessed', () {
    final recording = JigRecorder.record(<JigEvent>[
      // A runtime that predates `selectorSpec`: only the human sentence exists.
      _verbEvent('tap', <String, Object?>{'selector': "key 'add'"}),
      _verbEvent('tap', <String, Object?>{
        'selectorSpec': _spec(SelectorKind.key, 'save'),
      }, seq: 2),
    ]);

    // Nothing invented from `describe()`: a regex guess could record a selector
    // that never matched what was touched.
    expect(recording.steps, hasLength(1));
    expect(recording.skippedEvents, 1);
    expect(recording.toJson()['steps'], <Map<String, Object?>>[
      <String, Object?>{'verb': 'tap', 'key': 'save'},
    ]);
  });

  test('a verb that needs an argument is skipped when the argument is missing', () {
    final recording = JigRecorder.record(<JigEvent>[
      _verbEvent('type', <String, Object?>{
        'selectorSpec': _spec(SelectorKind.key, 'name'),
      }),
      _verbEvent('swipe', <String, Object?>{
        'selectorSpec': _spec(SelectorKind.key, 'row'),
      }, seq: 2),
    ]);

    // A `type` with no text would replay as typing nothing, which passes while
    // proving nothing.
    expect(recording.steps, isEmpty);
    expect(recording.skippedEvents, 2);
  });

  test('back needs no selector and is still recorded', () {
    // `back` is a whole step on its own; the app emits it without a selectorSpec, so
    // treating every selector-less event as unrecordable dropped it silently.
    final recording = JigRecorder.record(<JigEvent>[
      _verbEvent('tap', <String, Object?>{
        'selectorSpec': _spec(SelectorKind.key, 'go'),
      }),
      _verbEvent('back', <String, Object?>{'from': '/b', 'route': '/a'}, seq: 2),
    ]);

    expect(recording.skippedEvents, 0);
    expect(recording.toJson()['steps'], <Map<String, Object?>>[
      <String, Object?>{'verb': 'tap', 'key': 'go'},
      <String, Object?>{'verb': 'back'},
    ]);
  });

  test('events that are not verbs are ignored, not counted as failures', () {
    final recording = JigRecorder.record(<JigEvent>[
      JigEvent(
        seq: 1,
        source: JigSource.nav,
        kind: 'push',
        atMs: 0,
        data: const <String, Object?>{'route': '/a'},
      ),
      JigEvent(
        seq: 2,
        source: JigSource.custom,
        kind: 'installed',
        atMs: 0,
        data: const <String, Object?>{},
      ),
      _verbEvent('tap', <String, Object?>{
        'selectorSpec': _spec(SelectorKind.key, 'go'),
      }, seq: 3),
    ]);

    expect(recording.steps, hasLength(1));
    expect(recording.skippedEvents, 0);
  });
}
