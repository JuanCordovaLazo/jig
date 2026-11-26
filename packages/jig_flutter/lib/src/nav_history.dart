import 'package:flutter/widgets.dart';
import 'package:jig_protocol/jig_protocol.dart';

import 'bus.dart';

/// Route transitions, kept in a small ring so `jig state route` and `jig events
/// --sources nav` can answer "how did we get here".
abstract final class JigNavHistory {
  static const int _capacity = 64;

  static final List<Map<String, Object?>> _entries = <Map<String, Object?>>[];

  static List<Map<String, Object?>> get entries =>
      List<Map<String, Object?>>.unmodifiable(_entries);

  static String? get current =>
      _entries.isEmpty ? null : _entries.last['route'] as String?;

  static int _popCount = 0;

  /// How many routes have been removed since the app started.
  ///
  /// A back request can be intercepted and reported as handled while nothing
  /// moves - `PopScope(canPop: false)` does exactly that, and
  /// `handlePopRoute()` still answers `true`. Comparing this counter across a
  /// request is how a refusal is told apart from a real pop.
  static int get popCount => _popCount;

  static void recordPop() => _popCount++;

  static void record(String action, {String? route, String? previous}) {
    final entry = <String, Object?>{
      'action': action,
      'route': ?route,
      'previous': ?previous,
      'at': DateTime.now().millisecondsSinceEpoch,
    };
    _entries.add(entry);
    if (_entries.length > _capacity) {
      _entries.removeAt(0);
    }
    JigBus.instance.emit(JigSource.nav, action, entry);
  }

  static void clear() => _entries.clear();
}

/// A plain [NavigatorObserver]. Lives in the core package so an app that does not
/// use GetX can still record navigation; `jig_getx` adds the GetX-specific one.
class JigNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    JigNavHistory.record(
      'push',
      route: route.settings.name,
      previous: previousRoute?.settings.name,
    );
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    JigNavHistory.recordPop();
    JigNavHistory.record(
      'pop',
      route: previousRoute?.settings.name,
      previous: route.settings.name,
    );
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    JigNavHistory.recordPop();
    JigNavHistory.record(
      'remove',
      route: route.settings.name,
      previous: previousRoute?.settings.name,
    );
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    JigNavHistory.record(
      'replace',
      route: newRoute?.settings.name,
      previous: oldRoute?.settings.name,
    );
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
