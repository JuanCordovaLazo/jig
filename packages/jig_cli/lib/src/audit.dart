import 'package:jig_protocol/jig_protocol.dart';

/// One thing worth fixing about how an app exposes itself to a harness.
final class JigAuditFinding {
  const JigAuditFinding({
    required this.severity,
    required this.kind,
    required this.detail,
    this.refs = const <String>[],
    this.label,
    this.key,
    this.ownerType,
  });

  /// `error` when no stable selector exists, `warn` when one does.
  final String severity;

  /// `unaddressable`, `unlabelled` or `ambiguous`.
  final String kind;

  final String detail;
  final List<String> refs;
  final String? label;
  final String? key;
  final String? ownerType;

  bool get isError => severity == JigAudit.error;

  Map<String, Object?> toJson() => <String, Object?>{
    'severity': severity,
    'kind': kind,
    'detail': detail,
    if (refs.isNotEmpty) 'refs': refs,
    if (label != null) 'label': label,
    if (key != null) 'key': key,
    if (ownerType != null) 'ownerType': ownerType,
  };
}

/// The result of an audit.
///
/// Typed so the exit-code decision is testable without a connection: the part of
/// `--strict` that could silently rot is the judgement, not the printing.
final class JigAuditReport {
  const JigAuditReport({
    required this.scanned,
    required this.interactive,
    required this.addressed,
    required this.findings,
  });

  final int scanned;
  final int interactive;
  final int addressed;
  final List<JigAuditFinding> findings;

  int get errors => findings.where((JigAuditFinding f) => f.isError).length;

  int get warnings => findings.where((JigAuditFinding f) => !f.isError).length;

  /// Whether a `--strict` run should fail.
  ///
  /// Errors only: a warning means a stable selector exists, and failing on those
  /// would make the gate unusable on any real app.
  bool get blocks => errors > 0;

  Map<String, Object?> toJson() => <String, Object?>{
    'scanned': scanned,
    'interactive': interactive,
    'addressed': addressed,
    'counts': <String, int>{JigAudit.error: errors, JigAudit.warn: warnings},
    'findings': findings.map((JigAuditFinding f) => f.toJson()).toList(),
  };
}

/// Accessibility debt, derived from a listing.
///
/// Every finding is a statement about what a caller can *do*, not about style: an
/// element with no label and no key has no stable selector, and a label shared by
/// two controls makes `--sem` pick one silently. Both are the failure mode this
/// project exists to remove, so they are reported before they are hit.
abstract final class JigAudit {
  static const String error = 'error';
  static const String warn = 'warn';

  static JigAuditReport run(List<JigElement> elements) {
    final interactive = elements
        .where((JigElement element) => element.actions.isNotEmpty)
        .toList(growable: false);

    final findings = <JigAuditFinding>[
      for (final element in interactive)
        if (_labelOf(element) == null)
          element.key == null
              ? JigAuditFinding(
                  severity: error,
                  kind: 'unaddressable',
                  detail:
                      'Interactive, with no label and no key: only the widget '
                      'type and its index can name it, which stops working the '
                      'moment the screen changes.',
                  refs: <String>[element.ref],
                  ownerType: element.ownerType,
                )
              : JigAuditFinding(
                  severity: warn,
                  kind: 'unlabelled',
                  detail:
                      'Selectable by key, but invisible to a screen reader and '
                      'to every label-based selector.',
                  refs: <String>[element.ref],
                  key: element.key,
                  ownerType: element.ownerType,
                ),
      ..._duplicateLabels(interactive),
    ];

    // Counted by element, not by finding: `ambiguous` reports several elements in
    // one finding, so subtracting the finding count would overstate how many
    // controls are fine.
    final flagged = <String>{
      for (final finding in findings) ...finding.refs,
    };

    return JigAuditReport(
      scanned: elements.length,
      interactive: interactive.length,
      addressed: interactive.length - flagged.length,
      findings: findings,
    );
  }

  /// The label a selector would match on, or null when there is none to match.
  static String? _labelOf(JigElement element) {
    final label = normalise(element.label);
    return label.isEmpty ? null : label;
  }

  /// Labels shared by more than one interactive element.
  ///
  /// Normalised the same way matching normalises them, because the ambiguity that
  /// hurts is the one a selector will actually hit: `Guardar` and ` guardar `
  /// collide at the call site even though they differ in the listing.
  static List<JigAuditFinding> _duplicateLabels(List<JigElement> interactive) {
    final byLabel = <String, List<JigElement>>{};
    for (final element in interactive) {
      final label = _labelOf(element);
      if (label == null) {
        continue;
      }
      byLabel.putIfAbsent(label, () => <JigElement>[]).add(element);
    }

    return <JigAuditFinding>[
      for (final entry in byLabel.entries)
        if (entry.value.length > 1)
          JigAuditFinding(
            severity: warn,
            kind: 'ambiguous',
            detail:
                '${entry.value.length} interactive elements share this label, so '
                'a label selector resolves to one of them silently.',
            refs: entry.value
                .map((JigElement e) => e.ref)
                .toList(growable: false),
            label: entry.key,
          ),
    ];
  }

  static String normalise(String? raw) =>
      (raw ?? '').replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
}
