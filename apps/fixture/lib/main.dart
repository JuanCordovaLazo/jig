import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jig_flutter/jig_flutter.dart';

import 'controllers.dart';
import 'fake_backend.dart';
import 'pages/back_gate_page.dart';
import 'pages/buggy_page.dart';
import 'pages/form_page.dart';
import 'pages/home_page.dart';
import 'pages/live_list_page.dart';
import 'pages/nested_scroll_page.dart';
import 'pages/opaque_page.dart';
import 'pages/overlays_page.dart';
import 'pages/refresh_page.dart';
import 'pages/scroll_page.dart';
import 'pages/slidable_page.dart';
import 'pages/sliver_page.dart';
import 'pages/stacked_dialogs_page.dart';
import 'pages/tabs_page.dart';
import 'routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    // The only line an app needs. No custom binding, no overlay, no animation.
    Jig.install();
  }

  final backend = await FakeBackend.start();
  Get.put(backend, permanent: true);
  Get.put(ApiController(backend.base), permanent: true);
  Get.put(FormController(), permanent: true);
  Get.put(CartController(), permanent: true);
  Get.put(FeedController(), permanent: true);
  Get.put(BuggyController(), permanent: true);
  Get.put(DialogController(), permanent: true);
  Get.put(RefreshController(), permanent: true);

  _registerStateReaders();

  runApp(const FixtureApp());
}

/// Named readers are the reliable half of introspection: no source evaluation,
/// no generics, one extension call for the whole snapshot.
void _registerStateReaders() {
  Jig.state('route', () => Get.currentRoute);
  Jig.state('form.rating', () => Get.find<FormController>().rating.value);
  Jig.state('cart.count', () => Get.find<CartController>().count.value);
  Jig.state('cart.total', () => Get.find<CartController>().total.value);
  Jig.state('feed.size', () => Get.find<FeedController>().items.length);
  Jig.state('feed.shuffling', () => Get.find<FeedController>().isShuffling);
  Jig.state('api.last', () => Get.find<ApiController>().lastStatus.value);
  Jig.state('buggy.step', () => Get.find<BuggyController>().step.value);
  Jig.state('dialog.result', () => Get.find<DialogController>().lastResult.value);
  Jig.state('refresh.count', () => Get.find<RefreshController>().count.value);
}

class FixtureApp extends StatelessWidget {
  const FixtureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'jig fixture',
      debugShowCheckedModeBanner: false,
      initialRoute: FixtureRoutes.home,
      getPages: <GetPage<dynamic>>[
        GetPage<dynamic>(
          name: FixtureRoutes.home,
          page: () => const HomePage(),
        ),
        GetPage<dynamic>(
          name: FixtureRoutes.overlays,
          page: () => const OverlaysPage(),
        ),
        GetPage<dynamic>(
          name: FixtureRoutes.liveList,
          page: () => const LiveListPage(),
        ),
        GetPage<dynamic>(
          name: FixtureRoutes.form,
          page: () => const FormPage(),
        ),
        GetPage<dynamic>(
          name: FixtureRoutes.scroll,
          page: () => const ScrollPage(),
        ),
        GetPage<dynamic>(
          name: FixtureRoutes.opaque,
          page: () => const OpaquePage(),
        ),
        GetPage<dynamic>(
          name: FixtureRoutes.buggy,
          page: () => const BuggyPage(),
        ),
        GetPage<dynamic>(
          name: FixtureRoutes.sliver,
          page: () => const SliverPage(),
        ),
        GetPage<dynamic>(
          name: FixtureRoutes.nestedScroll,
          page: () => const NestedScrollPage(),
        ),
        GetPage<dynamic>(
          name: FixtureRoutes.tabs,
          page: () => const TabsPage(),
        ),
        GetPage<dynamic>(
          name: FixtureRoutes.backGate,
          page: () => const BackGatePage(),
        ),
        GetPage<dynamic>(
          name: FixtureRoutes.stackedDialogs,
          page: () => const StackedDialogsPage(),
        ),
        GetPage<dynamic>(
          name: FixtureRoutes.refresh,
          page: () => const RefreshPage(),
        ),
        GetPage<dynamic>(
          name: FixtureRoutes.slidable,
          page: () => const SlidablePage(),
        ),
      ],
      // Captures every printInfo in the app without touching a call site.
      logWriterCallback: Jig.logWriter,
      navigatorObservers: <NavigatorObserver>[Jig.navigatorObserver],
    );
  }
}
