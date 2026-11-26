import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jig_fixture/controllers.dart';
import 'package:jig_fixture/pages/form_page.dart';
import 'package:jig_flutter/jig_flutter.dart';
import 'package:jig_protocol/jig_protocol.dart';

import 'support/jig_harness.dart';

/// A slider advertises `increase` and `decrease`, never `tap`. Before this verb
/// existed the only way to move one was to give up, so these are the checks that
/// make the capability real rather than nominal.
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

  testWidgets('one step up moves the value, and the page agrees', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const FormPage(), () async {
      final result = await drive(
        tester,
        JigActions.adjust(JigSelector.key('rating_slider'), increase: true),
      );
      await tester.pump();

      // `divisions: 5` makes one step 20%, so 3.0 of 5 is 60% and becomes 80%.
      expect(result['previousValue'], '60%');
      expect(result['value'], '80%');
      expect(result['steps'], 1);

      // The page renders what it holds: a verb that reported a value the app never
      // took could not pass this.
      expect(Get.find<FormController>().rating.value, closeTo(4.0, 0.001));
      expect(find.text('Calificacion 4'), findsOneWidget);
    });
  });

  testWidgets('times applies that many steps and reports the total', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const FormPage(), () async {
      final result = await drive(
        tester,
        JigActions.adjust(
          JigSelector.key('rating_slider'),
          increase: false,
          times: 2,
        ),
      );

      expect(result['steps'], 2);
      expect(result['value'], '20%');
      expect(Get.find<FormController>().rating.value, closeTo(1.0, 0.001));
    });
  });

  testWidgets('a step past the end is refused, not reported as ok', (
    WidgetTester tester,
  ) async {
    Get.find<FormController>().rating.value = 5.0;
    await withPage(tester, const FormPage(), () async {
      final error = await driveFailure(
        tester,
        JigActions.adjust(JigSelector.key('rating_slider'), increase: true),
      );

      // The framework clamps `increasedValue` at the maximum, which is what makes
      // this refusable before anything is dispatched.
      expect(error?.code, JigErrorCode.adjustRefused);
      expect(error?.message, contains('maximum'));
      expect(Get.find<FormController>().rating.value, 5.0);
    });
  });

  testWidgets('a control with no steps is refused by name', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const FormPage(), () async {
      // `submit` is a button: it has `tap`, and no increase/decrease at all.
      final error = await driveFailure(
        tester,
        JigActions.adjust(JigSelector.key('submit'), increase: true),
      );

      expect(error?.code, JigErrorCode.adjustRefused);
      expect(error?.message, contains('increase'));
    });
  });

  testWidgets('the listing names the slider, not the boundary it builds', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const FormPage(), () async {
      // A `Slider` carries the key, but the node that advertises `increase` belongs
      // to a render object several levels below it. Finding the key in a listing is
      // the only way an agent learns it can name the control, so the key has to land
      // on the node that acts.
      final slider = JigElementIndex.capture().firstWhere(
        (JigElement e) => e.key == 'rating_slider',
      );
      expect(slider.actions, containsAll(<String>['increase', 'decrease']));
    });
  });

  testWidgets('the recorded step replays through a scenario step', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const FormPage(), () async {
      final result = await drive(
        tester,
        JigActions.adjust(
          JigSelector.key('rating_slider'),
          increase: true,
          times: 1,
        ),
      );

      // The bus is what `jig record` reads, so the event has to carry enough to
      // rebuild the step: the selector in spec form, the direction and the count.
      final events = JigBus.instance.since(0, sources: <JigSource>{JigSource.custom});
      final adjustEvent = events.lastWhere((JigEvent e) => e.kind == 'adjust');
      expect(adjustEvent.data['direction'], 'up');
      expect(adjustEvent.data['times'], 1);
      expect(adjustEvent.data['selectorSpec'], isA<Map<String, Object?>>());
      expect(result['value'], '80%');
    });
  });
}
