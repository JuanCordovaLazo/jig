import 'package:jig_driver/jig_driver.dart';
import 'package:jig_protocol/jig_protocol.dart';

import 'scenario.dart';

/// What happened on one step.
final class JigStepResult {
  const JigStepResult({
    required this.index,
    required this.verb,
    required this.status,
    this.elapsedMs = 0,
    this.error,
  });

  final int index;
  final String verb;

  /// `ok`, `failed` or `skipped`.
  final String status;

  final int elapsedMs;
  final JigError? error;

  Map<String, Object?> toJson() => <String, Object?>{
    'step': index + 1,
    'verb': verb,
    'status': status,
    'elapsedMs': elapsedMs,
    if (error != null) 'error': error!.toJson(),
  };
}

/// The outcome of a whole scenario.
final class JigRunReport {
  const JigRunReport({
    required this.scenario,
    required this.steps,
    required this.stoppedAt,
  });

  final String scenario;
  final List<JigStepResult> steps;

  /// Zero-based index of the step that failed, or null when all passed.
  final int? stoppedAt;

  bool get ok => stoppedAt == null;

  int get passed => steps.where((JigStepResult s) => s.status == 'ok').length;

  int get skipped =>
      steps.where((JigStepResult s) => s.status == 'skipped').length;

  Map<String, Object?> toJson() => <String, Object?>{
    'scenario': scenario,
    'ok': ok,
    'passed': passed,
    'skipped': skipped,
    'failed': ok ? 0 : 1,
    'steps': steps.map((JigStepResult s) => s.toJson()).toList(),
  };
}

/// Executes a scenario against the app, one step at a time.
///
/// Stops at the first failure and marks the rest `skipped` rather than dropping
/// them: a report that simply ends early reads like a shorter scenario, and the
/// whole point of this project is that a report says what happened.
abstract final class JigRunner {
  static Future<JigRunReport> run(
    JigVerbs verbs,
    JigScenario scenario,
  ) async {
    final results = <JigStepResult>[];
    int? stoppedAt;

    for (final step in scenario.steps) {
      if (stoppedAt != null) {
        results.add(
          JigStepResult(index: step.index, verb: step.verb, status: 'skipped'),
        );
        continue;
      }

      final watch = Stopwatch()..start();
      final JigError? error = await _execute(verbs, step);
      watch.stop();

      if (error == null) {
        results.add(
          JigStepResult(
            index: step.index,
            verb: step.verb,
            status: 'ok',
            elapsedMs: watch.elapsedMilliseconds,
          ),
        );
        continue;
      }

      stoppedAt = step.index;
      results.add(
        JigStepResult(
          index: step.index,
          verb: step.verb,
          status: 'failed',
          elapsedMs: watch.elapsedMilliseconds,
          error: error,
        ),
      );
    }

    return JigRunReport(
      scenario: scenario.name,
      steps: results,
      stoppedAt: stoppedAt,
    );
  }

  /// Runs one step, returning the error it produced or null when it passed.
  static Future<JigError?> _execute(
    JigVerbs verbs,
    JigScenarioStep step,
  ) async {
    try {
      switch (step.verb) {
        case 'ping':
          return _of(await verbs.ping());

        case 'nav':
          return _of(await verbs.nav());

        case 'back':
          return _of(await verbs.back());

        case 'tree':
          return _of(
            await verbs.tree(interactiveOnly: true, limit: step.limit ?? 120),
          );

        case 'events':
          return _of(
            await verbs.events(
              since: step.since ?? 0,
              sources: step.sources,
              limit: step.limit ?? 100,
            ),
          );

        case 'tap':
          if (step.ref != null) {
            return _of(await verbs.tapRef(step.ref!));
          }
          return _of(await verbs.tap(_required(step)));

        case 'type':
          final value = step.value;
          if (value == null) {
            return _badScenario(step, 'a type step needs "value"');
          }
          if (value.isEmpty) {
            return _badScenario(
              step,
              'an empty "value" does not clear a field: use a clear step',
            );
          }
          return _of(await verbs.typeText(_required(step), value));

        case 'clear':
          return _of(await verbs.clear(_required(step)));

        case 'adjust':
          return _of(
            await verbs.adjust(
              _required(step),
              direction: step.direction ?? 'up',
              times: step.times ?? 1,
            ),
          );

        case 'swipe':
          final direction = step.direction;
          if (direction == null) {
            return _badScenario(step, 'a swipe step needs "direction"');
          }
          return _of(await verbs.swipe(_required(step), direction: direction));

        case 'wait':
          return _of(
            await verbs.wait(
              _required(step),
              present: step.present,
              timeout: step.timeout,
            ),
          );

        case 'scroll':
          return _of(
            await verbs.scroll(
              _required(step),
              horizontal: step.horizontal,
              steps: step.steps,
              within: step.within,
            ),
          );

        case 'state':
          return await _state(verbs, step);

        default:
          return _badScenario(step, '"${step.verb}" has no runner');
      }
    } on JigScenarioException catch (error) {
      return JigError(JigErrorCode.invalidSelector, error.toString());
    }
  }

  /// Reads the readers a step asked for, then checks what it expected.
  static Future<JigError?> _state(
    JigVerbs verbs,
    JigScenarioStep step,
  ) async {
    final response = await verbs.state(
      names: step.expect.isNotEmpty ? step.expect.keys : step.names,
    );
    final failure = _of(response);
    if (failure != null) {
      return failure;
    }
    if (step.expect.isEmpty) {
      return null;
    }

    final raw = response.data?['values'];
    if (raw is! List<Object?>) {
      return JigError(
        JigErrorCode.expectationFailed,
        'The app returned no state to compare against',
        hint: 'Register the name with Jig.state(...) in the app.',
      );
    }

    // The wire shape is `{count, values: [{name, value|error, type}]}` - a list, not
    // a map keyed by name. Reading it as a map is how this verb first failed on a
    // device while a value that was plainly there looked missing.
    final byName = <String, Map<String, Object?>>{
      for (final entry in raw)
        if (entry is Map<String, Object?> && entry['name'] is String)
          entry['name']! as String: entry,
    };

    for (final expected in step.expect.entries) {
      final entry = byName[expected.key];
      if (entry == null) {
        return JigError(
          JigErrorCode.expectationFailed,
          '${expected.key} is not registered in the app',
          hint: 'Register it with Jig.state(...) before the scenario runs.',
        );
      }
      final readerError = entry['error'];
      if (readerError != null) {
        return JigError(
          JigErrorCode.expectationFailed,
          '${expected.key} could not be read: $readerError',
          hint: 'Fix the reader, or register a different one.',
        );
      }
      final actual = entry['value'];
      if (actual != expected.value) {
        return JigError(
          JigErrorCode.expectationFailed,
          '${expected.key} was ${_show(actual)}, '
          'expected ${_show(expected.value)}',
          candidates: <String>['${expected.key}=${_show(actual)}'],
          hint: 'jig state --names ${expected.key}',
        );
      }
    }
    return null;
  }

  static JigSelector _required(JigScenarioStep step) {
    final selector = step.selector;
    if (selector == null) {
      throw JigScenarioException(
        'a ${step.verb} step needs one of "sem", "key", "type" or "text"',
        step: step.index,
      );
    }
    return selector;
  }

  static JigError? _badScenario(JigScenarioStep step, String message) {
    return JigError(
      JigErrorCode.invalidSelector,
      message,
      hint: 'Step ${step.index + 1} of the scenario is malformed.',
    );
  }

  static JigError? _of(JigResponse response) => response.error;

  static String _show(Object? value) => value == null ? 'null' : '$value';
}
