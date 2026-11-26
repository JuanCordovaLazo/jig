import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers.dart';

/// Rows move every 120 ms. A harness that resolves a position and then dispatches
/// a pointer event has a window in which that position belongs to another row;
/// a harness that addresses a semantics node does not.
class LiveListPage extends StatelessWidget {
  const LiveListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<FeedController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Live list')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Obx(
              () => FilledButton(
                key: const ValueKey<String>('toggle_shuffle'),
                onPressed: controller.toggleShuffle,
                child: Text(
                  controller.isShuffling ? 'Detener' : 'Mezclar filas',
                ),
              ),
            ),
          ),
          Expanded(
            child: Obx(
              () => ListView(
                children: <Widget>[
                  for (final id in controller.items)
                    ListTile(
                      key: ValueKey<String>('row_$id'),
                      title: Text('Fila $id'),
                      trailing: const Icon(Icons.drag_handle),
                      onTap: () => Get.snackbar('Fila', '$id'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
