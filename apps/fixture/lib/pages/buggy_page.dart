import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers.dart';

/// A flow with a real bug: step two writes step one, so it never reaches 2.
///
/// The point is to keep the harness honest. A scenario that only checks "the
/// button was tapped without throwing" passes here; a scenario that waits for
/// `buggy.step == 2` fails, which is the behaviour worth trusting.
class BuggyPage extends StatelessWidget {
  const BuggyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BuggyController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Buggy flow')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Obx(
              () => Text(
                'Paso actual: ${controller.step.value}',
                key: const ValueKey<String>('buggy_step_label'),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey<String>('buggy_step_one'),
              onPressed: controller.advance,
              child: const Text('Paso uno'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey<String>('buggy_step_two'),
              onPressed: controller.confirm,
              child: const Text('Paso dos'),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              key: const ValueKey<String>('buggy_reset'),
              onPressed: controller.reset,
              child: const Text('Reiniciar'),
            ),
          ],
        ),
      ),
    );
  }
}
