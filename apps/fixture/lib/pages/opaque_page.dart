import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Two tappables that look alike. Only one is in the accessibility tree.
///
/// This is the case `jig audit` is for: the unlabelled one is invisible to any
/// semantics-driven harness, and the fix belongs in the app (add [Semantics]),
/// not in the harness (guess by position).
class OpaquePage extends StatelessWidget {
  const OpaquePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Opaque widget')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'El primer recuadro no expone semantica. jig no puede verlo, '
              'y eso es correcto: la correccion es agregar Semantics al widget.',
            ),
            const SizedBox(height: 16),
            GestureDetector(
              key: const ValueKey<String>('opaque_target'),
              // A design-system tappable that never opted into semantics: no
              // gesture semantics and no text in the accessibility tree. The
              // fix belongs in the app, not in the harness.
              excludeFromSemantics: true,
              onTap: () => Get.snackbar('Opaque', 'Tocado sin semantica'),
              child: Container(
                height: 64,
                alignment: Alignment.center,
                color: Colors.amber,
                child: const ExcludeSemantics(
                  child: Text('Invisible para jig'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              key: const ValueKey<String>('labelled_target'),
              onTap: () => Get.snackbar('Labelled', 'Tocado con semantica'),
              child: Semantics(
                label: 'Objetivo etiquetado',
                button: true,
                child: Container(
                  height: 64,
                  alignment: Alignment.center,
                  color: Colors.lightGreen,
                  child: const Text('Visible para jig'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
