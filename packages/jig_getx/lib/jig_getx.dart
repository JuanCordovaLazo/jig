/// GetX adapter for jig.
///
/// The HTTP side lives here because tracing it needs [GetConnect]. Navigation
/// does not need an adapter: `Jig.navigatorObserver` is a plain
/// [NavigatorObserver], which `GetMaterialApp` accepts as-is.
library;

export 'src/jig_connect.dart';
