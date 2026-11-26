import 'package:flutter/material.dart';

/// A route that refuses the first back request, the way an app guarding
/// unsaved input does. A harness that calls `Navigator.pop` directly would pop
/// this and call it a pass.
class BackGatePage extends StatefulWidget {
  const BackGatePage({super.key});

  @override
  State<BackGatePage> createState() => _BackGatePageState();
}

class _BackGatePageState extends State<BackGatePage> {
  bool _confirmed = false;
  bool _prompting = false;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: _confirmed,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        setState(() => _prompting = true);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Back gate')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'The first back request is refused on purpose. Confirm, then '
                  'the next one leaves.',
                  textAlign: TextAlign.center,
                ),
              ),
              if (_prompting) ...<Widget>[
                const SizedBox(height: 16),
                ElevatedButton(
                  key: const ValueKey<String>('confirm_leave'),
                  onPressed: () => setState(() {
                    _confirmed = true;
                    _prompting = false;
                  }),
                  child: const Text('Allow leaving'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
