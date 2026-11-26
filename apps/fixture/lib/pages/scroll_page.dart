import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 500 rows, almost all off screen. Proves that selection does not depend on
/// what happens to be rendered, and that scrolling can be driven by target
/// rather than by pixel delta.
class ScrollPage extends StatelessWidget {
  const ScrollPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Long scroll')),
      // Opens a modal over the list, so the covered-row case has a way to happen.
      floatingActionButton: FloatingActionButton(
        key: const ValueKey<String>('scroll_open_dialog'),
        onPressed: () => Get.dialog<void>(
          AlertDialog(
            title: const Text('Dialog over the list'),
            content: const Text('The rows behind this dialog are not reachable.'),
            actions: <Widget>[
              TextButton(
                key: const ValueKey<String>('scroll_dialog_close'),
                onPressed: () => Get.back<void>(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
        child: const Icon(Icons.lock_outline),
      ),
      body: ListView.builder(
        key: const ValueKey<String>('long_list'),
        itemCount: 500,
        itemBuilder: (context, index) => ListTile(
          key: ValueKey<String>('item_$index'),
          title: Text('Elemento $index'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Get.snackbar('Elemento', '$index'),
        ),
      ),
    );
  }
}
