import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers.dart';

/// Pull-to-refresh, which needs a pointer path and therefore the `swipe` verb.
///
/// The refresh records itself through [RefreshController] so the harness can prove
/// it happened. A gesture that misses the indicator leaves the count alone, which is
/// the difference between a proved gesture and a reported one.
class RefreshPage extends StatelessWidget {
  const RefreshPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<RefreshController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Pull to refresh')),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future<void>.delayed(const Duration(milliseconds: 400));
          controller.count.value += 1;
        },
        child: ListView.builder(
          key: const ValueKey<String>('refresh_list'),
          itemCount: 30,
          itemBuilder: (BuildContext context, int index) => ListTile(
            key: ValueKey<String>('refresh_row_$index'),
            title: Text('Refresh row $index'),
          ),
        ),
      ),
    );
  }
}
