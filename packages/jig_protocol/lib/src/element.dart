import 'rect.dart';

/// One actionable or readable node, as reported to the agent.
///
/// [ref] is a handle the caller may pass back to act on this exact node. It is
/// only valid for the app session that produced it; anything longer lived must
/// use a [JigSelector] instead.
final class JigElement {
  const JigElement({
    required this.ref,
    required this.kind,
    this.label,
    this.value,
    this.hint,
    this.key,
    this.ownerType,
    this.rect,
    this.actions = const <String>[],
    this.depth = 0,
  });

  final String ref;
  final String kind;
  final String? label;
  final String? value;
  final String? hint;

  /// The [Key] the owning widget carries, when it has one. This is the most
  /// stable selector in the contract, so a listing that omits it leaves the
  /// caller guessing.
  final String? key;

  /// Runtime type of the widget that owns the semantics node.
  ///
  /// Reported because a control with no label - an icon-only button, say - has
  /// no other stable handle. It is the widget type, not the framework plumbing
  /// under it, so a `ListTile` is reported rather than the `InkWell` inside it.
  final String? ownerType;

  /// Bounds on screen. Informational only - see [JigRect].
  final JigRect? rect;

  final List<String> actions;
  final int depth;

  bool get isInteractive => actions.isNotEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
        'ref': ref,
        'kind': kind,
        if (label != null && label!.isNotEmpty) 'label': label,
        if (value != null && value!.isNotEmpty) 'value': value,
        if (hint != null && hint!.isNotEmpty) 'hint': hint,
        if (key != null) 'key': key,
        if (ownerType != null) 'ownerType': ownerType,
        if (rect != null) 'rect': rect!.toJson(),
        if (actions.isNotEmpty) 'actions': actions,
        if (depth != 0) 'depth': depth,
      };

  static JigElement fromJson(Map<String, Object?> json) => JigElement(
        ref: json['ref']! as String,
        kind: json['kind']! as String,
        label: json['label'] as String?,
        value: json['value'] as String?,
        hint: json['hint'] as String?,
        key: json['key'] as String?,
        ownerType: json['ownerType'] as String?,
        rect: json['rect'] == null
            ? null
            : JigRect.fromJson(
                (json['rect']! as Map<Object?, Object?>).cast<String, Object?>(),
              ),
        actions: (json['actions'] as List<Object?>? ?? const <Object?>[])
            .cast<String>(),
        depth: json['depth'] as int? ?? 0,
      );

  @override
  String toString() =>
      'JigElement($ref, $kind, label: $label, actions: $actions)';
}
