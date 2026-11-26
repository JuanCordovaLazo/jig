/// App-side runtime for jig.
///
/// Call [Jig.install] from `main` behind `kDebugMode`, wire `Jig.logWriter` into
/// the app's logger and `JigNavigatorObserver` into the navigator, and the
/// extensions become reachable from `jig_cli`.
///
/// This package has no dependency on any state management library on purpose:
/// adopting jig must not choose an architecture for the app.
library;

export 'src/actions.dart';
export 'src/bus.dart';
export 'src/element_index.dart';
export 'src/jig.dart';
export 'src/nav_history.dart';
export 'src/state_registry.dart';
