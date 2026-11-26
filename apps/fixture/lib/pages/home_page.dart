import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../insets.dart';
import '../routes.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('jig fixture'),
        // Icon-only and deliberately unlabelled. 76 of these exist in the app
        // this harness was built for, and a label-only listing cannot name any of
        // them - `ownerType` is what makes them addressable.
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Get.snackbar('Icon', 'leading'),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.star_border),
            onPressed: () => Get.snackbar('Icon', 'trailing'),
          ),
        ],
      ),
      body: ListView(
        padding: pagePadding(context),
        children: const <Widget>[
          Text(
            'Each screen reproduces one failure mode on purpose. '
            'Read docs/fixture-matrix.md before changing them.',
          ),
          SizedBox(height: 16),
          _Tile(
            route: FixtureRoutes.overlays,
            title: 'Overlays',
            subtitle: 'GetX snackbar, dialog and bottom sheet over a target',
          ),
          _Tile(
            route: FixtureRoutes.liveList,
            title: 'Live list',
            subtitle: 'Rows reorder every 120 ms while you try to tap them',
          ),
          _Tile(
            route: FixtureRoutes.form,
            title: 'Form',
            subtitle: 'TextField, checkbox and slider',
          ),
          _Tile(
            route: FixtureRoutes.scroll,
            title: 'Long scroll',
            subtitle: '500 rows, most of them off screen',
          ),
          _Tile(
            route: FixtureRoutes.opaque,
            title: 'Opaque widget',
            subtitle: 'A tappable with no semantics, next to a labelled one',
          ),
          _Tile(
            route: FixtureRoutes.buggy,
            title: 'Buggy flow',
            subtitle: 'Step two never advances: a scenario must fail here',
          ),
          _Tile(
            route: FixtureRoutes.sliver,
            title: 'Sliver scroll',
            subtitle: 'CustomScrollView with the target 55 rows down',
          ),
          _Tile(
            route: FixtureRoutes.nestedScroll,
            title: 'Nested scrollables',
            subtitle: 'A ListView inside a SingleChildScrollView',
          ),
          _Tile(
            route: FixtureRoutes.tabs,
            title: 'Horizontal tabs',
            subtitle: 'The target is on the second tab, on the other axis',
          ),
          _Tile(
            route: FixtureRoutes.backGate,
            title: 'Back gate',
            subtitle: 'PopScope refuses the first back request',
          ),
          _Tile(
            route: FixtureRoutes.stackedDialogs,
            title: 'Stacked dialogs',
            subtitle: 'A sheet over a dialog whose result reaches a reader',
          ),
          _Tile(
            route: FixtureRoutes.refresh,
            title: 'Pull to refresh',
            subtitle: 'Needs a drag: expected to stay red',
          ),
          _Tile(
            route: FixtureRoutes.slidable,
            title: 'Swipe actions',
            subtitle: 'Needs a drag: expected to stay red',
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.route,
    required this.title,
    required this.subtitle,
  });

  final String route;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        key: ValueKey<String>('nav_$route'),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Get.toNamed<dynamic>(route),
      ),
    );
  }
}
