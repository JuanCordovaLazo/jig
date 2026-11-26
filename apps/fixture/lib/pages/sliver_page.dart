import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A sliver list: the scroll node is a viewport rather than the obvious
/// ancestor, and rows below the fold are never built. Reaching the target has to
/// be proven by paging, not by arithmetic on indices.
class SliverPage extends StatelessWidget {
  const SliverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sliver scroll')),
      body: CustomScrollView(
        key: const ValueKey<String>('sliver_scroll'),
        slivers: <Widget>[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Row 55 sits far below the fold.'),
            ),
          ),
          SliverList.builder(
            itemCount: 60,
            itemBuilder: (BuildContext context, int index) => ListTile(
              key: ValueKey<String>('sliver_$index'),
              title: Text('Sliver $index'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.snackbar('Sliver', '$index'),
            ),
          ),
        ],
      ),
    );
  }
}
