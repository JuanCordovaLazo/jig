/// How a caller points at something to act on.
///
/// Ordered by stability, most stable first. Raw screen coordinates are
/// deliberately absent: a coordinate is a guess that silently expires when the
/// app rebuilds, which is the failure mode this project exists to avoid.
enum SelectorKind { key, semantic, widgetType, text }

final class JigSelector {
  const JigSelector._(this.kind, this.value, {this.index = 0, this.exact = true});

  /// Matches the widget carrying this [Key] value.
  const JigSelector.key(String key) : this._(SelectorKind.key, key);

  /// Matches the accessibility label the widget renders.
  const JigSelector.semantic(String label, {bool exact = true})
      : this._(SelectorKind.semantic, label, exact: exact);

  /// Matches the widget runtime type, disambiguated by [index] when the same
  /// type appears more than once.
  const JigSelector.widgetType(String type, {int index = 0})
      : this._(SelectorKind.widgetType, type, index: index);

  /// Matches visible text content, for widgets that expose no label.
  const JigSelector.text(String text) : this._(SelectorKind.text, text);

  final SelectorKind kind;
  final String value;
  final int index;
  final bool exact;

  Map<String, Object?> toJson() => <String, Object?>{
        'kind': kind.name,
        'value': value,
        if (index != 0) 'index': index,
        if (!exact) 'exact': false,
      };

  static JigSelector fromJson(Map<String, Object?> json) {
    final kind = SelectorKind.values.byName(json['kind']! as String);
    final value = json['value']! as String;
    return switch (kind) {
      SelectorKind.key => JigSelector.key(value),
      SelectorKind.semantic =>
        JigSelector.semantic(value, exact: json['exact'] as bool? ?? true),
      SelectorKind.widgetType =>
        JigSelector.widgetType(value, index: json['index'] as int? ?? 0),
      SelectorKind.text => JigSelector.text(value),
    };
  }

  /// Human-readable form used in error messages and hints.
  String describe() => switch (kind) {
        SelectorKind.key => "key '$value'",
        SelectorKind.semantic => "label '$value'",
        SelectorKind.widgetType =>
          "type '$value'${index == 0 ? '' : ' #$index'}",
        SelectorKind.text => "text '$value'",
      };

  @override
  String toString() => 'JigSelector(${describe()})';
}
