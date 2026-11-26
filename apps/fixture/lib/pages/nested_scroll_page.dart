import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Two scrollables on one screen. Paging the wrong one either does nothing
/// observable or loses the inner position, so the caller has to name one.
class NestedScrollPage extends StatelessWidget {
  const NestedScrollPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nested scrollables')),
      body: SingleChildScrollView(
        key: const ValueKey<String>('outer_scroll'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < 5; i++)
              SizedBox(
                height: 90,
                child: Center(child: Text('Outer block $i')),
              ),
            SizedBox(
              height: 240,
              child: ListView.builder(
                key: const ValueKey<String>('inner_list'),
                itemCount: 40,
                itemBuilder: (BuildContext context, int index) => ListTile(
                  key: ValueKey<String>('inner_$index'),
                  title: Text('Inner $index'),
                  onTap: () => Get.snackbar('Inner', '$index'),
                ),
              ),
            ),
            for (int i = 0; i < 5; i++)
              SizedBox(
                height: 90,
                child: Center(child: Text('Outer tail $i')),
              ),
            ListTile(
              key: const ValueKey<String>('outer_target'),
              title: const Text('Outer target'),
              trailing: const Icon(Icons.flag),
              onTap: () => Get.snackbar('Outer', 'target'),
            ),
          ],
        ),
      ),
    );
  }
}
