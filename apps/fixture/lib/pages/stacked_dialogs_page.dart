import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers.dart';

/// A dialog with a sheet stacked on top, and a result that has to reach a
/// registered reader. Dismissing modals in the wrong order would take the route
/// with them.
class StackedDialogsPage extends StatelessWidget {
  const StackedDialogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stacked dialogs')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('A dialog, and a sheet on top of it.'),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const ValueKey<String>('open_dialog'),
              onPressed: _open,
              child: const Text('Open dialog'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open() async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Stacked dialogs'),
        content: const Text('Open a sheet over this dialog, or confirm it.'),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('dialog_open_sheet'),
            onPressed: () => Get.bottomSheet<void>(const _SheetPanel()),
            child: const Text('Open sheet'),
          ),
          TextButton(
            key: const ValueKey<String>('dialog_confirm'),
            onPressed: () => Get.back<bool>(result: true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    Get.find<DialogController>().lastResult.value =
        result == true ? 'confirmed' : 'dismissed';
  }
}

class _SheetPanel extends StatelessWidget {
  const _SheetPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('sheet_panel'),
      height: 180,
      color: Colors.white,
      child: Center(
        child: ElevatedButton(
          key: const ValueKey<String>('sheet_close'),
          onPressed: () => Get.back<void>(),
          child: const Text('Close sheet'),
        ),
      ),
    );
  }
}
