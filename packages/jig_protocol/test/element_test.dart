import 'dart:convert';

import 'package:jig_protocol/jig_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('JigElement', () {
    test('round-trips the selectors a caller needs', () {
      const element = JigElement(
        ref: 'n7',
        kind: 'semantics',
        label: 'Overlays',
        key: 'nav_/overlays',
        ownerType: 'ListTile',
        rect: JigRect(x: 0, y: 96, width: 380, height: 72),
        actions: <String>['tap'],
        depth: 3,
      );

      final decoded = JigElement.fromJson(
        jsonDecode(jsonEncode(element.toJson())) as Map<String, Object?>,
      );

      expect(decoded.ref, 'n7');
      expect(decoded.key, 'nav_/overlays');
      expect(decoded.ownerType, 'ListTile');
      expect(decoded.rect, const JigRect(x: 0, y: 96, width: 380, height: 72));
      expect(decoded.actions, <String>['tap']);
      expect(decoded.depth, 3);
    });

    test('omits bounds and owner type when the node has neither', () {
      const element = JigElement(ref: 'n1', kind: 'semantics');

      final json = element.toJson();

      expect(json.containsKey('rect'), isFalse);
      expect(json.containsKey('ownerType'), isFalse);
      expect(json.containsKey('key'), isFalse);

      final decoded = JigElement.fromJson(json);
      expect(decoded.rect, isNull);
      expect(decoded.ownerType, isNull);
    });

    test('reads a node whose payload omits optional fields', () {
      final decoded = JigElement.fromJson(<String, Object?>{
        'ref': 'n2',
        'kind': 'semantics',
        'actions': <Object?>['tap'],
      });

      expect(decoded.key, isNull);
      expect(decoded.ownerType, isNull);
      expect(decoded.rect, isNull);
    });
  });

  group('JigRect', () {
    test('decodes integer-valued coordinates', () {
      final rect = JigRect.fromJson(<String, Object?>{
        'x': 0,
        'y': 12,
        'width': 100,
        'height': 48,
      });

      expect(rect.y, 12.0);
      expect(rect.width, 100.0);
    });

    test('compares by value', () {
      expect(
        const JigRect(x: 1, y: 2, width: 3, height: 4),
        const JigRect(x: 1, y: 2, width: 3, height: 4),
      );
      expect(
        const JigRect(x: 1, y: 2, width: 3, height: 4),
        isNot(const JigRect(x: 1, y: 2, width: 3, height: 5)),
      );
    });
  });
}
