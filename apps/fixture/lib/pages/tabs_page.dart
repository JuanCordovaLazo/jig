import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Horizontal paging. A `TabBarView` moves on the other axis, which is the case
/// a vertical-only scroll implementation silently gets wrong.
class TabsPage extends StatelessWidget {
  const TabsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Horizontal tabs'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'One'),
              Tab(text: 'Two'),
              Tab(text: 'Three'),
            ],
          ),
        ),
        body: TabBarView(
          key: const ValueKey<String>('tabs_view'),
          children: <Widget>[
            const Center(child: Text('First tab')),
            ListView(
              children: <Widget>[
                for (int i = 0; i < 8; i++)
                  ListTile(title: Text('Second tab row $i')),
                ListTile(
                  key: const ValueKey<String>('second_tab_target'),
                  title: const Text('Second tab target'),
                  trailing: const Icon(Icons.star),
                  onTap: () => Get.snackbar('Second', 'target'),
                ),
              ],
            ),
            const Center(child: Text('Third tab')),
          ],
        ),
      ),
    );
  }
}
