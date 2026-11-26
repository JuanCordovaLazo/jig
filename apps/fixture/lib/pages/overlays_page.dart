import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../insets.dart';

/// The case that made coordinate-based harnesses tap the wrong thing: the
/// overlay sits above the target, and the target's position is still "valid".
///
/// With semantics, the target leaves the tree while a modal route is on top, so
/// acting on it fails loudly instead of hitting the barrier.
class OverlaysPage extends StatelessWidget {
  const OverlaysPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Overlays')),
      body: Padding(
        // The target below is bottom-anchored, so the bottom inset is the one
        // that decides whether it sits under the navigation bar.
        padding: pagePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            FilledButton(
              key: const ValueKey<String>('show_snackbar'),
              onPressed: () => Get.snackbar(
                'Snackbar abierto',
                'Toca Confirmar en el dialogo, no el objetivo',
              ),
              child: const Text('Abrir snackbar'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey<String>('show_dialog'),
              onPressed: () => Get.dialog<void>(
                AlertDialog(
                  title: const Text('Dialogo'),
                  content: const Text('El objetivo de abajo sigue en pantalla.'),
                  actions: <Widget>[
                    TextButton(
                      key: const ValueKey<String>('dialog_confirm'),
                      onPressed: () => Get.back<void>(),
                      child: const Text('Confirmar'),
                    ),
                  ],
                ),
              ),
              child: const Text('Abrir dialogo'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey<String>('show_sheet'),
              onPressed: () => Get.bottomSheet<void>(
                Container(
                  // Full-bleed background, inset content: the sheet looks like it
                  // reaches the edge and its button still clears the nav bar.
                  padding: pagePadding(context, all: 24),
                  color: Colors.white,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('Hoja inferior'),
                      const SizedBox(height: 8),
                      FilledButton(
                        key: const ValueKey<String>('sheet_close'),
                        onPressed: () => Get.back<void>(),
                        child: const Text('Cerrar hoja'),
                      ),
                    ],
                  ),
                ),
              ),
              child: const Text('Abrir bottom sheet'),
            ),
            const Spacer(),
            FilledButton(
              key: const ValueKey<String>('overlay_target'),
              onPressed: () => Get.snackbar('Objetivo', 'Tocado'),
              child: const Text('Objetivo'),
            ),
          ],
        ),
      ),
    );
  }
}
