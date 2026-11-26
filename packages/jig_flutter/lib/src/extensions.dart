import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:jig_protocol/jig_protocol.dart';

import 'actions.dart';
import 'bus.dart';
import 'element_index.dart';
import 'nav_history.dart';
import 'state_registry.dart';

typedef _ExtensionHandler =
    Future<Map<String, Object?>> Function(Map<String, String> params);

/// The VM service surface. Eleven entries, and that is the whole contract.
abstract final class JigExtensions {
  static bool _registered = false;

  static void register() {
    if (_registered) {
      return;
    }
    _registered = true;
    _bind('ext.jig.ping', _ping);
    _bind('ext.jig.elements', elements);
    _bind('ext.jig.tap', _tap);
    _bind('ext.jig.type', _type);
    _bind('ext.jig.wait', _wait);
    _bind('ext.jig.events', _events);
    _bind('ext.jig.state', _state);
    _bind('ext.jig.nav', _nav);
    _bind('ext.jig.back', _back);
    _bind('ext.jig.scroll', _scroll);
    _bind('ext.jig.screenshot', _screenshot);
  }

  static void _bind(String name, _ExtensionHandler handler) {
    try {
      developer.registerExtension(name, (
        String method,
        Map<String, String> params,
      ) async {
        // Timing lives here rather than in each handler so the envelope's
        // elapsedMs is always the real cost of the call.
        final stopwatch = Stopwatch()..start();
        try {
          final data = await handler(params);
          stopwatch.stop();
          return _result(
            JigResponse.ok(
              data,
              seq: JigBus.instance.seq,
              elapsedMs: stopwatch.elapsedMilliseconds,
            ),
          );
        } on JigActionFailure catch (failure) {
          stopwatch.stop();
          return _result(
            JigResponse.failure(
              failure.error,
              seq: JigBus.instance.seq,
              elapsedMs: stopwatch.elapsedMilliseconds,
            ),
          );
        } catch (error, stack) {
          stopwatch.stop();
          return _result(
            JigResponse.failure(
              JigError(
                JigErrorCode.internal,
                error.toString(),
                hint: stack.toString().split('\n').take(3).join(' | '),
              ),
              seq: JigBus.instance.seq,
              elapsedMs: stopwatch.elapsedMilliseconds,
            ),
          );
        }
      });
    } catch (_) {
      // No VM service available: a release build, or no debugger attached.
    }
  }

  // ---------------------------------------------------------------- handlers

  static Future<Map<String, Object?>> _ping(Map<String, String> params) async {
    return <String, Object?>{
      'protocol': jigProtocolVersion,
      'seq': JigBus.instance.seq,
      'buffered': JigBus.instance.length,
      'state': JigStateRegistry.names,
      'route': JigNavHistory.current,
    };
  }

  /// The `elements` payload, without the VM service envelope.
  ///
  /// Public so the zero-result contract - an empty list always arrives with a
  /// reason - can be asserted without a device. It is the only handler exposed
  /// this way, and it widens nothing: this class is not exported by the barrel, so
  /// the ten-extension surface apps see is unchanged.
  static Future<Map<String, Object?>> elements(
    Map<String, String> params,
  ) async {
    final interactiveOnly = params['interactive'] != 'false';
    final limit = int.tryParse(params['limit'] ?? '') ?? 120;
    final query = params['q']?.toLowerCase();

    var elements = JigElementIndex.capture(
      interactiveOnly: interactiveOnly,
      limit: limit,
    );
    if (query != null && query.isNotEmpty) {
      // The key is searched too, and that is not a nicety: a caller who already
      // knows the key it wants has no other way to ask. Filtering on label and
      // value alone answered `q: slid` with nothing while `nav_/slidable` was on
      // screen, which sends an agent looking for the wrong thing.
      elements = elements
          .where(
            (element) =>
                (element.label ?? '').toLowerCase().contains(query) ||
                (element.value ?? '').toLowerCase().contains(query) ||
                (element.key ?? '').toLowerCase().contains(query),
          )
          .toList(growable: false);
    }

    return <String, Object?>{
      'count': elements.length,
      'elements': elements.map((element) => element.toJson()).toList(),
      'diag': JigElementIndex.diagnostics(),
    };
  }

  static Future<Map<String, Object?>> _tap(Map<String, String> params) async {
    // One extension carries every way of acting on an element, because that budget
    // is the contract cost and none of these is a new capability to negotiate: a
    // swipe is an action without a semantics node, and a step is the action a range
    // control advertises instead of `tap`.
    if (params['action'] == 'increase' || params['action'] == 'decrease') {
      return JigActions.adjust(
        _parseSelector(params),
        increase: params['action'] == 'increase',
        times: int.tryParse(params['times'] ?? '') ?? 1,
      );
    }
    if (params['gesture'] == 'swipe') {
      final direction = JigSwipeDirection.parse(params['direction']);
      if (direction == null) {
        throw const JigActionFailure(
          JigError(
            JigErrorCode.invalidSelector,
            'A swipe needs direction=left|right|up|down',
            hint: 'jig swipe --key <key> --direction left',
          ),
        );
      }
      return JigActions.swipe(
        _parseSelector(params),
        direction: direction,
        ref: params['ref'],
      );
    }
    final ref = params['ref'];
    if (ref != null && ref.isNotEmpty) {
      return JigActions.tapRef(ref);
    }
    return JigActions.tap(
      _parseSelector(params),
      long: params['long'] == 'true',
    );
  }

  static Future<Map<String, Object?>> _type(Map<String, String> params) async {
    // `clear` is the same capability - set the text of a field - and rides this
    // extension so the surface stays one entry per capability. It is a separate
    // verb because it proves the result instead of reporting what it sent.
    if (params['clear'] == 'true') {
      return JigActions.clearText(_parseSelector(params));
    }
    final value = params['value'] ?? '';
    return JigActions.typeText(_parseSelector(params), value);
  }

  static Future<Map<String, Object?>> _screenshot(
    Map<String, String> params,
  ) {
    return JigActions.screenshot(
      pixelRatio: double.tryParse(params['pixelRatio'] ?? '') ?? 1,
    );
  }

  static Future<Map<String, Object?>> _wait(Map<String, String> params) async {
    final selector = _parseSelector(params);
    final timeoutMs = int.tryParse(params['timeoutMs'] ?? '') ?? 5000;
    final wantPresent = (params['kind'] ?? 'present') != 'absent';

    // The reported figure is the wait that actually happened, not the budget:
    // a caller that sees `waitedMs: 10000` cannot tell a timeout from an
    // immediate match, which is the kind of lie this whole project removes.
    final stopwatch = Stopwatch()..start();
    final reached = await _waitUntil(
      () => JigActions.isPresent(selector) == wantPresent,
      timeoutMs,
    );
    stopwatch.stop();
    if (!reached) {
      throw JigActionFailure(
        JigError(
          JigErrorCode.timeout,
          'Timed out after ${timeoutMs}ms waiting for ${selector.describe()} '
          'to be ${wantPresent ? 'present' : 'absent'}',
          candidates: JigElementIndex.labels(),
          hint: 'jig tree',
        ),
      );
    }
    return <String, Object?>{'waitedMs': stopwatch.elapsedMilliseconds};
  }

  static Future<Map<String, Object?>> _events(
    Map<String, String> params,
  ) async {
    final since = int.tryParse(params['since'] ?? '') ?? 0;
    final limit = int.tryParse(params['limit'] ?? '') ?? 100;
    final events = JigBus.instance.since(
      since,
      sources: _parseSources(params['sources']),
      limit: limit,
    );
    return <String, Object?>{
      'seq': JigBus.instance.seq,
      'count': events.length,
      'events': events.map((event) => event.toJson()).toList(),
    };
  }

  static Future<Map<String, Object?>> _state(Map<String, String> params) async {
    final raw = params['names'];
    final only = raw == null || raw.isEmpty
        ? null
        : raw
              .split(',')
              .map((name) => name.trim())
              .where((name) => name.isNotEmpty);
    final snapshot = JigStateRegistry.snapshot(only: only);
    return <String, Object?>{
      'count': snapshot.length,
      'values': snapshot.values.map((entry) => entry.toJson()).toList(),
    };
  }

  static Future<Map<String, Object?>> _nav(Map<String, String> params) async {
    return <String, Object?>{
      'current': JigNavHistory.current,
      'entries': JigNavHistory.entries,
    };
  }

  static Future<Map<String, Object?>> _back(Map<String, String> params) {
    return JigActions.back();
  }

  static Future<Map<String, Object?>> _scroll(Map<String, String> params) {
    final selector = _parseSelector(params);
    final horizontal = params['axis'] == 'horizontal';
    final steps = int.tryParse(params['steps'] ?? '') ?? 20;
    return JigActions.scrollUntil(
      selector,
      horizontal: horizontal,
      steps: steps,
      within: params['in'],
    );
  }

  // ----------------------------------------------------------------- helpers

  /// Polls inside the UI isolate. Same-thread polling is the point: there is no
  /// round trip between the check and the frame that would satisfy it.
  static Future<bool> _waitUntil(bool Function() predicate, int timeoutMs) {
    final completer = Completer<bool>();
    final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
    Timer.periodic(const Duration(milliseconds: 16), (Timer handle) {
      var satisfied = false;
      try {
        satisfied = predicate();
      } catch (_) {
        satisfied = false;
      }
      if (satisfied) {
        handle.cancel();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
        return;
      }
      if (DateTime.now().isAfter(deadline)) {
        handle.cancel();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      }
    });
    return completer.future;
  }

  static Set<JigSource>? _parseSources(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return raw
        .split(',')
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .map(
          (name) => JigSource.values.firstWhere(
            (source) => source.name == name,
            orElse: () => JigSource.custom,
          ),
        )
        .toSet();
  }

  static JigSelector _parseSelector(Map<String, String> params) {
    final semantic = params['semantic'];
    if (semantic != null && semantic.isNotEmpty) {
      return JigSelector.semantic(semantic, exact: params['exact'] != 'false');
    }
    final key = params['key'];
    if (key != null && key.isNotEmpty) {
      return JigSelector.key(key);
    }
    final type = params['type'];
    if (type != null && type.isNotEmpty) {
      return JigSelector.widgetType(
        type,
        index: int.tryParse(params['index'] ?? '') ?? 0,
      );
    }
    final text = params['text'];
    if (text != null && text.isNotEmpty) {
      return JigSelector.text(text);
    }
    throw const JigActionFailure(
      JigError(
        JigErrorCode.invalidSelector,
        'Provide one of: semantic, key, type, text',
        hint: "jig find --sem '<label>'",
      ),
    );
  }

  static developer.ServiceExtensionResponse _result(JigResponse response) {
    return developer.ServiceExtensionResponse.result(
      jsonEncode(response.toJson()),
    );
  }
}
