import 'package:jig_protocol/jig_protocol.dart';

/// Turns the verb events an app emitted into scenario steps.
///
/// The app already records what it was asked to do, so recording is a translation
/// rather than an interception: no daemon, no second process, and the same events a
/// caller would read with `jig events`.
abstract final class JigRecorder {
  /// The verbs that become steps, keyed by the event kind `JigActions` emits.
  static const Set<String> verbs = <String>{
    'tap',
    'type',
    'clear',
    'adjust',
    'scroll',
    'swipe',
    'back',
  };

  /// Verbs that need no selector: the whole step is the verb.
  static const Set<String> selectorless = <String>{'back'};

  static JigRecording record(
    List<JigEvent> events, {
    String name = 'recorded',
    String? note,
  }) {
    final steps = <Map<String, Object?>>[];
    var skipped = 0;

    for (final event in events) {
      if (event.source != JigSource.custom || !verbs.contains(event.kind)) {
        continue;
      }

      if (selectorless.contains(event.kind)) {
        steps.add(<String, Object?>{'verb': event.kind});
        continue;
      }

      final spec = event.data['selectorSpec'];
      if (spec is! Map<String, Object?>) {
        // No structured selector: this event came from a runtime that predates it.
        // Guessing one back from the human sentence would write a step that may not
        // match what was actually touched, so it is counted and left out.
        skipped++;
        continue;
      }

      final selector = JigSelector.fromJson(spec);
      final step = <String, Object?>{'verb': event.kind, ..._selectorFields(selector)};

      switch (event.kind) {
        case 'type':
          final value = event.data['text'];
          if (value is! String) {
            skipped++;
            continue;
          }
          step['value'] = value;
        case 'adjust':
          final direction = event.data['direction'];
          final times = event.data['times'];
          if (direction is! String) {
            skipped++;
            continue;
          }
          step['direction'] = direction;
          if (times is num && times.toInt() != 1) {
            step['times'] = times.toInt();
          }
        case 'swipe':
          final direction = event.data['direction'];
          if (direction is! String) {
            skipped++;
            continue;
          }
          step['direction'] = direction;
        case 'scroll':
          final steps = event.data['steps'];
          if (steps is num) {
            step['steps'] = steps.toInt();
          }
      }

      steps.add(step);
    }

    return JigRecording(
      name: name,
      steps: steps,
      skippedEvents: skipped,
      note: note,
    );
  }

  /// The selector in the flat form `JigScenario.parse` accepts.
  ///
  /// One key per kind, mirroring the CLI flags, so a recorded file reads like the
  /// commands that produced it.
  static Map<String, Object?> _selectorFields(JigSelector selector) {
    return switch (selector.kind) {
      SelectorKind.key => <String, Object?>{'key': selector.value},
      SelectorKind.semantic => <String, Object?>{
        'sem': selector.value,
        if (!selector.exact) 'exact': false,
      },
      SelectorKind.widgetType => <String, Object?>{
        'type': selector.value,
        if (selector.index != 0) 'index': selector.index,
      },
      SelectorKind.text => <String, Object?>{'text': selector.value},
    };
  }
}

/// A scenario written from what happened, plus how much could not be written.
final class JigRecording {
  const JigRecording({
    required this.name,
    required this.steps,
    required this.skippedEvents,
    this.note,
  });

  final String name;
  final List<Map<String, Object?>> steps;
  final int skippedEvents;
  final String? note;

  /// The scenario document, ready to be written to disk and replayed by `jig run`.
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    if (note != null) 'note': note,
    'steps': steps,
  };
}
