import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jig_fixture/controllers.dart';
import 'package:jig_fixture/pages/form_page.dart';
import 'package:jig_flutter/jig_flutter.dart';
import 'package:jig_protocol/jig_protocol.dart';

import 'support/jig_harness.dart';

void main() {
  setUp(() {
    JigNavHistory.clear();
    Get.reset();
    Get.put(FormController());
    Jig.state('form.rating', () => Get.find<FormController>().rating.value);
  });

  tearDown(() {
    JigStateRegistry.unregister('form.rating');
    Get.reset();
  });

  testWidgets('typing reaches the field, and submit sees the typed value', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const FormPage(), () async {
      // Text entry is not a tap: the field only advertises `setText` once it has
      // focus, and focusing is part of the verb rather than a step to remember.
      await drive(
        tester,
        JigActions.typeText(JigSelector.semantic('Nombre'), 'Ana'),
      );

      expect(JigActions.tap(JigSelector.key('submit'))['action'], 'tap');
      await tester.pump();

      // The page renders what it received, so a verb that typed into the wrong
      // place cannot pass by reporting success.
      expect(find.text('Enviado: Ana|false|3'), findsOneWidget);
    });
  });

  testWidgets('clear leaves the field empty, and submitting proves it', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const FormPage(), () async {
      await drive(
        tester,
        JigActions.typeText(JigSelector.semantic('Nombre'), 'Ana'),
      );
      await drive(
        tester,
        JigActions.clearText(JigSelector.semantic('Nombre')),
      );

      // The page renders what it holds, so an empty submission is the app saying
      // the field is empty rather than the verb claiming it.
      JigActions.tap(JigSelector.key('submit'));
      await tester.pump();
      expect(find.text('Enviado: |false|3'), findsOneWidget);
    });
  });

  testWidgets('a field that puts text back makes clear fail, not lie', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const _MaskedField(), () async {
      await drive(
        tester,
        JigActions.typeText(JigSelector.semantic('Codigo'), 'ABC'),
      );

      final error = await driveFailure(
        tester,
        JigActions.clearText(JigSelector.semantic('Codigo')),
      );

      // The mask re-adds its prefix, so the field cannot become empty. Reporting
      // success here is the defect the verb exists to catch.
      expect(error?.code, JigErrorCode.clearRefused);
      expect(error?.message, contains('>'));
    });
  });
}

/// A field whose formatter always keeps a prefix, so it can never be emptied.
class _MaskedField extends StatelessWidget {
  const _MaskedField();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextField(
          key: const ValueKey<String>('masked_field'),
          decoration: const InputDecoration(labelText: 'Codigo'),
          inputFormatters: <TextInputFormatter>[_PrefixFormatter()],
        ),
      ),
    );
  }
}

class _PrefixFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: '>${newValue.text}',
      selection: TextSelection.collapsed(offset: newValue.text.length + 1),
    );
  }
}
