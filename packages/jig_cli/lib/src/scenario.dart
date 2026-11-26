import 'dart:convert';

import 'package:jig_protocol/jig_protocol.dart';

/// Raised when a scenario document is not something the runner can execute.
///
/// Separate from a failed step: a malformed scenario is the caller's mistake and
/// must not be reported as an app failure, or every typo looks like a bug in jig.
final class JigScenarioException implements Exception {
  const JigScenarioException(this.message, {this.step});

  final String message;

  /// Zero-based index of the offending step, when it is known.
  final int? step;

  @override
  String toString() =>
      step == null ? message : 'step ${step! + 1}: $message';
}

/// One executable line of a scenario.
final class JigScenarioStep {
  const JigScenarioStep({
    required this.index,
    required this.verb,
    this.selector,
    this.ref,
    this.value,
    this.direction,
    this.present = true,
    this.times,
    this.timeout = const Duration(seconds: 10),
    this.steps = 20,
    this.horizontal = false,
    this.within,
    this.names,
    this.expect = const <String, Object?>{},
    this.limit,
    this.since,
    this.sources,
  });

  final int index;
  final String verb;
  final JigSelector? selector;
  final String? ref;
  final String? value;
  final String? direction;
  final bool present;

  /// How many steps an `adjust` applies. Null means the verb's default of 1.
  final int? times;
  final Duration timeout;
  final int steps;
  final bool horizontal;
  final String? within;
  final List<String>? names;

  /// Expected values for registered readers, keyed by reader name.
  final Map<String, Object?> expect;

  final int? limit;
  final int? since;
  final Set<JigSource>? sources;
}

/// A parsed scenario.
final class JigScenario {
  const JigScenario({required this.name, required this.steps});

  final String name;
  final List<JigScenarioStep> steps;

  /// The verbs a scenario may use.
  ///
  /// `eval` is deliberately absent: it takes a free-form expression the other
  /// verbs do not, and pretending it fits the same shape would make the format
  /// worse for every other verb.
  static const Set<String> verbs = <String>{
    'ping',
    'tree',
    'tap',
    'tapRef',
    'type',
    'clear',
    'adjust',
    'swipe',
    'wait',
    'scroll',
    'state',
    'events',
    'nav',
    'back',
  };

  static JigScenario parse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw JigScenarioException('The scenario is not valid JSON: ${error.message}');
    }
    if (decoded is! Map<String, Object?>) {
      throw const JigScenarioException('The scenario must be a JSON object');
    }

    final rawSteps = decoded['steps'];
    if (rawSteps is! List<Object?> || rawSteps.isEmpty) {
      throw const JigScenarioException('The scenario needs a non-empty "steps" list');
    }

    final steps = <JigScenarioStep>[
      for (var index = 0; index < rawSteps.length; index++)
        _step(rawSteps[index], index),
    ];

    return JigScenario(
      name: (decoded['name'] as String?) ?? 'unnamed',
      steps: steps,
    );
  }

  static JigScenarioStep _step(Object? raw, int index) {
    if (raw is! Map<String, Object?>) {
      throw JigScenarioException('Each step must be an object', step: index);
    }
    final verb = raw['verb'];
    if (verb is! String || !verbs.contains(verb)) {
      throw JigScenarioException(
        '"${verb ?? ''}" is not a step verb. One of: ${verbs.join(', ')}',
        step: index,
      );
    }

    final expect = raw['expect'];
    if (expect != null && expect is! Map<String, Object?>) {
      throw JigScenarioException('"expect" must be an object', step: index);
    }

    return JigScenarioStep(
      index: index,
      verb: verb,
      selector: _selector(raw, index),
      ref: raw['ref'] as String?,
      value: raw['value'] as String?,
      direction: raw['direction'] as String?,
      present: raw['present'] as bool? ?? true,
      times: _positiveInt(raw['times'], index),
      timeout: _duration(raw['timeoutMs'], index),
      steps: _positiveInt(raw['steps'], index) ?? 20,
      horizontal: raw['axis'] == 'horizontal',
      within: raw['in'] as String?,
      names: _stringList(raw['names'], index),
      expect: (expect as Map<String, Object?>?) ?? const <String, Object?>{},
      limit: _positiveInt(raw['limit'], index),
      since: _positiveInt(raw['since'], index),
      sources: _sources(raw['sources'], index),
    );
  }

  /// The selector, from whichever key the step supplied.
  ///
  /// Mirrors the CLI flags so a scenario reads like the commands it replaces, and
  /// so an agent that can write one can write the other.
  static JigSelector? _selector(Map<String, Object?> raw, int index) {
    final semantic = raw['sem'];
    final key = raw['key'];
    final type = raw['type'];
    final text = raw['text'];
    if (semantic is String && semantic.isNotEmpty) {
      return JigSelector.semantic(
        semantic,
        exact: raw['exact'] as bool? ?? true,
      );
    }
    if (key is String && key.isNotEmpty) {
      return JigSelector.key(key);
    }
    if (type is String && type.isNotEmpty) {
      return JigSelector.widgetType(
        type,
        index: _positiveInt(raw['index'], index) ?? 0,
      );
    }
    if (text is String && text.isNotEmpty) {
      return JigSelector.text(text);
    }
    return null;
  }

  static Duration _duration(Object? raw, int index) {
    final millis = _positiveInt(raw, index) ?? 10000;
    return Duration(milliseconds: millis);
  }

  static int? _positiveInt(Object? raw, int index) {
    if (raw == null) {
      return null;
    }
    if (raw is int && raw >= 0) {
      return raw;
    }
    throw JigScenarioException('"$raw" is not a non-negative integer', step: index);
  }

  static List<String>? _stringList(Object? raw, int index) {
    if (raw == null) {
      return null;
    }
    if (raw is List<Object?> && raw.every((Object? e) => e is String)) {
      return raw.cast<String>();
    }
    throw JigScenarioException('"$raw" is not a list of names', step: index);
  }

  static Set<JigSource>? _sources(Object? raw, int index) {
    final names = _stringList(raw, index);
    if (names == null) {
      return null;
    }
    return <JigSource>{
      for (final name in names)
        JigSource.values.firstWhere(
          (JigSource source) => source.name == name,
          orElse: () => throw JigScenarioException(
            '"$name" is not an event source',
            step: index,
          ),
        ),
    };
  }
}
