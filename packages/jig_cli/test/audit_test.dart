import 'package:jig_cli/src/audit.dart';
import 'package:jig_protocol/jig_protocol.dart';
import 'package:test/test.dart';

JigElement _element(
  String ref, {
  String? label,
  String? key,
  String? ownerType,
  List<String> actions = const <String>['tap'],
}) => JigElement(
  ref: ref,
  kind: 'semantics',
  label: label,
  key: key,
  ownerType: ownerType,
  actions: actions,
);

JigAuditFinding _only(JigAuditReport report, String kind) =>
    report.findings.singleWhere((JigAuditFinding f) => f.kind == kind);

void main() {
  group('severity reflects what the caller can do', () {
    test('no label and no key is an error, because nothing can name it', () {
      final report = JigAudit.run(<JigElement>[
        _element('n1', ownerType: 'IconButton'),
      ]);

      final finding = _only(report, 'unaddressable');
      expect(finding.severity, JigAudit.error);
      expect(finding.refs, <String>['n1']);
      expect(finding.ownerType, 'IconButton');
      expect(report.errors, 1);
      expect(report.warnings, 0);
    });

    test('the same control with a key is only a warning', () {
      final report = JigAudit.run(<JigElement>[
        _element('n1', key: 'save', ownerType: 'IconButton'),
      ]);

      final finding = _only(report, 'unlabelled');
      expect(finding.severity, JigAudit.warn);
      expect(finding.key, 'save');

      // A key is a real selector, so this must not be reported as an error: the
      // point of the severity split is that the two are not the same problem.
      expect(report.errors, 0);
      expect(report.warnings, 1);
    });

    test('a label shared by two controls is ambiguous, at the label selector', () {
      final report = JigAudit.run(<JigElement>[
        _element('n1', label: 'Guardar'),
        _element('n2', label: '  guardar  '),
      ]);

      // Normalised on purpose: the collision a caller hits is the one matching
      // hits, not the one a string comparison would see.
      final finding = _only(report, 'ambiguous');
      expect(finding.label, 'guardar');
      expect(finding.refs, <String>['n1', 'n2']);
      expect(finding.severity, JigAudit.warn);
    });
  });

  group('what it counts', () {
    test('a well-addressed screen has no findings and counts every element', () {
      final report = JigAudit.run(<JigElement>[
        _element('n1', label: 'Guardar', key: 'save'),
        _element('n2', label: 'Cancelar'),
      ]);

      expect(report.findings, isEmpty);
      expect(report.scanned, 2);
      expect(report.interactive, 2);
      expect(report.addressed, 2);
    });

    test('non-interactive nodes are scanned but never flagged', () {
      final report = JigAudit.run(<JigElement>[
        _element('n1', label: 'Un titulo', actions: <String>[]),
        _element('n2'),
      ]);

      expect(report.scanned, 2);
      expect(report.interactive, 1);
      // The unlabelled text is not something a caller needs to select.
      expect(_only(report, 'unaddressable').refs, <String>['n2']);
    });

    test('addressed counts elements, not findings, when labels group', () {
      final report = JigAudit.run(<JigElement>[
        _element('n1', label: 'Ok'),
        _element('n2', label: 'Ok'),
        _element('n3', label: 'Cerrar', key: 'close'),
      ]);

      // One ambiguous finding covers two elements, so a finding-based subtraction
      // would claim two addressed controls when only one is untouched.
      expect(report.addressed, 1);
    });
  });

  group('the strict gate', () {
    test('blocks only when a control has no stable selector', () {
      expect(JigAudit.run(<JigElement>[_element('n1')]).blocks, isTrue);

      // A warning still has a working selector, so it must not fail the run:
      // otherwise no real app could ever pass --strict.
      final warned = JigAudit.run(<JigElement>[
        _element('n1', key: 'save'),
        _element('n2', label: 'Ok'),
        _element('n3', label: 'Ok'),
      ]);
      expect(warned.blocks, isFalse);
      expect(warned.warnings, greaterThan(0));

      expect(JigAudit.run(const <JigElement>[]).blocks, isFalse);
    });

    test('the wire shape carries the counts and the findings', () {
      final json = JigAudit.run(<JigElement>[_element('n1')]).toJson();

      expect(json['counts'], <String, int>{
        JigAudit.error: 1,
        JigAudit.warn: 0,
      });
      expect(json['scanned'], 1);
      expect(json['interactive'], 1);
      expect(json['addressed'], 0);
      expect(json['findings']! as List<Object?>, hasLength(1));
    });
  });
}
