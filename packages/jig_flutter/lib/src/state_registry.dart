import 'package:jig_protocol/jig_protocol.dart';

/// Named readers for values the agent should not have to reconstruct.
///
/// The alternative is evaluating Dart source against the app at runtime, which
/// is powerful but fails on generics and needs a library scope. Named readers
/// are the reliable path: they are registered by the app, they survive
/// minification, and the snapshot is one extension call instead of N.
abstract final class JigStateRegistry {
  static final Map<String, Object? Function()> _readers =
      <String, Object? Function()>{};

  static List<String> get names => _readers.keys.toList(growable: false);

  static void register(String name, Object? Function() read) {
    _readers[name] = read;
  }

  static void unregister(String name) {
    _readers.remove(name);
  }

  static void clear() => _readers.clear();

  /// Values for [only], or for everything registered when it is null.
  ///
  /// A reader that throws is reported in place: one broken expression must not
  /// cost the caller the whole snapshot.
  static Map<String, JigStateEntry> snapshot({Iterable<String>? only}) {
    final selected = only ?? _readers.keys;
    final out = <String, JigStateEntry>{};
    for (final name in selected) {
      final reader = _readers[name];
      if (reader == null) {
        out[name] = JigStateEntry(
          name: name,
          error: 'not registered',
        );
        continue;
      }
      try {
        final value = reader();
        out[name] = JigStateEntry(
          name: name,
          value: _jsonSafe(value),
          type: value?.runtimeType.toString(),
        );
      } catch (error) {
        out[name] = JigStateEntry(name: name, error: error.toString());
      }
    }
    return out;
  }

  /// Coerces a value into something `jsonEncode` accepts, instead of letting a
  /// single custom object fail the whole response.
  static Object? _jsonSafe(Object? value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is Enum) {
      return value.name;
    }
    if (value is Iterable<Object?>) {
      return value.map(_jsonSafe).toList(growable: false);
    }
    if (value is Map<Object?, Object?>) {
      return <String, Object?>{
        for (final entry in value.entries)
          entry.key.toString(): _jsonSafe(entry.value),
      };
    }
    return value.toString();
  }
}
