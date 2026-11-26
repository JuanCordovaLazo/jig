/// A named value read from inside the app.
///
/// [error] is non-null when the reader threw: an expression that fails is
/// reported next to the ones that worked instead of failing the whole snapshot.
final class JigStateEntry {
  const JigStateEntry({required this.name, this.value, this.type, this.error});

  final String name;
  final Object? value;
  final String? type;
  final String? error;

  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        if (error != null) 'error': error else 'value': value,
        if (type != null) 'type': type,
      };

  static JigStateEntry fromJson(Map<String, Object?> json) => JigStateEntry(
        name: json['name']! as String,
        value: json['value'],
        type: json['type'] as String?,
        error: json['error'] as String?,
      );

  @override
  String toString() => error != null
      ? 'JigStateEntry($name: error $error)'
      : 'JigStateEntry($name: $value)';
}
