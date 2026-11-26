import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';

/// Swipe-to-reveal needs a pointer path too. The action buttons do not exist
/// until a drag happens, so this row stays red until gestures are in scope.
class SlidablePage extends StatelessWidget {
  const SlidablePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Swipe actions')),
      body: ListView(
        children: <Widget>[
          Slidable(
            key: const ValueKey<String>('slidable_row'),
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              children: <Widget>[
                SlidableAction(
                  key: const ValueKey<String>('slidable_delete'),
                  onPressed: (BuildContext context) =>
                      Get.snackbar('Swipe', 'delete'),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  icon: Icons.delete,
                  label: 'Delete',
                ),
              ],
            ),
            child: const ListTile(
              title: Text('Swipe me to reveal the action'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
          const ListTile(title: Text('A plain row, for contrast')),
        ],
      ),
    );
  }
}
