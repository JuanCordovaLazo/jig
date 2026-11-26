import 'dart:async';

import 'package:jig_protocol/jig_protocol.dart';
import 'package:vm_service/vm_service.dart' as vm;
import 'package:vm_service/vm_service_io.dart' as vm_io;

import 'verbs.dart';

/// Raised when a session cannot be established at all, as opposed to an action
/// that failed inside a healthy session.
final class JigConnectionException implements Exception {
  const JigConnectionException(this.message);

  final String message;

  @override
  String toString() => 'JigConnectionException: $message';
}

/// Result of evaluating a Dart expression against the app isolate.
final class JigEvalResult {
  const JigEvalResult({required this.ok, this.value, this.kind, this.error});

  final bool ok;
  final Object? value;
  final String? kind;
  final String? error;

  Map<String, Object?> toJson() => <String, Object?>{
        'ok': ok,
        if (ok) 'value': value,
        if (kind != null) 'kind': kind,
        if (error != null) 'error': error,
      };
}

/// A live connection to one app isolate.
final class JigConnection implements JigVerbs {
  JigConnection._(this._service, this._isolateId, this._rootLibraryId);

  final vm.VmService _service;
  final String _isolateId;
  final String? _rootLibraryId;

  String get isolateId => _isolateId;

  /// Connects to `ws://host:port/token=/ws` and verifies that jig is installed.
  ///
  /// Verification is deliberately eager: discovering that the extension is
  /// missing on the first real command makes the failure look like a bug in the
  /// command instead of a missing `Jig.install()`.
  ///
  /// [timeout] exists because the underlying socket has none. A session file left
  /// behind by a killed app can point at a host that neither accepts nor refuses -
  /// a filtered port, a suspended machine - and an unbounded connect then blocks for
  /// over two minutes before the caller hears anything. A client with its own
  /// startup deadline (an editor's MCP client, for one) gives up first and reports a
  /// server that never became ready, which says nothing about the real problem.
  static Future<JigConnection> attach(
    String wsUri, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final vm.VmService service;
    try {
      service = await vm_io.vmServiceConnectUri(wsUri).timeout(
        timeout,
        onTimeout: () => throw JigConnectionException(
          'cannot connect to $wsUri: no answer within ${timeout.inSeconds}s',
        ),
      );
    } on JigConnectionException {
      rethrow;
    } catch (error) {
      throw JigConnectionException('cannot connect to $wsUri: $error');
    }

    final vmInfo = await service.getVM();
    final isolates = vmInfo.isolates ?? const <vm.IsolateRef>[];
    if (isolates.isEmpty) {
      throw const JigConnectionException(
        'the VM service exposes no isolates; is the app still starting?',
      );
    }
    final isolate = isolates.firstWhere(
      (candidate) => candidate.name?.startsWith('main') ?? false,
      orElse: () => isolates.first,
    );
    final isolateId = isolate.id!;

    final isolateInfo = await service.getIsolate(isolateId);
    final connection =
        JigConnection._(service, isolateId, isolateInfo.rootLib?.id);

    final ping = await connection.call('ext.jig.ping');
    if (!ping.ok) {
      throw JigConnectionException(
        'jig is not reachable on this isolate (${ping.error?.message}). '
        'Call Jig.install() behind kDebugMode in main().',
      );
    }
    return connection;
  }

  Future<void> dispose() => _service.dispose();

  /// Calls one of the `ext.jig.*` extensions.
  Future<JigResponse> call(
    String method, [
    Map<String, String> args = const <String, String>{},
  ]) async {
    try {
      final result = await _service.callServiceExtension(
        method,
        isolateId: _isolateId,
        args: Map<String, dynamic>.from(args),
      );
      final json = result.json;
      if (json == null) {
        return JigResponse.failure(
          JigError(
            JigErrorCode.internal,
            '$method returned no payload',
          ),
        );
      }
      return JigResponse.fromJson(
        json.cast<String, Object?>(),
      );
    } on vm.RPCError catch (error) {
      final missing = error.code == 113 || error.message.contains('not found');
      return JigResponse.failure(
        JigError(
          missing
              ? JigErrorCode.extensionUnavailable
              : JigErrorCode.internal,
          error.message,
          hint: missing ? 'Call Jig.install() behind kDebugMode.' : null,
        ),
      );
    }
  }

  // ------------------------------------------------------------------- verbs

  @override
  Future<JigResponse> tree({
    bool interactiveOnly = true,
    int limit = 120,
    String? query,
  }) {
    return call('ext.jig.elements', <String, String>{
      'interactive': '$interactiveOnly',
      'limit': '$limit',
      'q': ?query,
    });
  }

  @override
  Future<JigResponse> tap(
    JigSelector selector, {
    bool long = false,
  }) {
    return call('ext.jig.tap', <String, String>{
      ..._selectorArgs(selector),
      'long': '$long',
    });
  }

  @override
  Future<JigResponse> tapRef(String ref) {
    return call('ext.jig.tap', <String, String>{'ref': ref});
  }

  /// Drags an element in a named direction.
  ///
  /// Same extension as [tap]: the wire has one gesture entry point, so the budget
  /// of ten stays a budget. The direction is a name rather than a delta, because a
  /// delta is a coordinate the caller would have had to guess.
  @override
  Future<JigResponse> swipe(
    JigSelector selector, {
    String direction = 'left',
    String? ref,
  }) {
    return call('ext.jig.tap', <String, String>{
      ..._selectorArgs(selector),
      'gesture': 'swipe',
      'direction': direction,
      if (ref != null && ref.isNotEmpty) 'ref': ref,
    });
  }

  @override
  Future<JigResponse> typeText(JigSelector selector, String value) {
    return call('ext.jig.type', <String, String>{
      ..._selectorArgs(selector),
      'value': value,
    });
  }

  /// Empties a field. Same extension as [typeText]: the capability is setting a
  /// field's text, and `clear` is the variant that reads the result back.
  @override
  Future<JigResponse> clear(JigSelector selector) {
    return call('ext.jig.type', <String, String>{
      ..._selectorArgs(selector),
      'clear': 'true',
    });
  }

  /// Moves a range control by whole steps.
  ///
  /// Same extension as [tap], because the wire carries "an action on an element"
  /// and `increase`/`decrease` are actions an element advertises. The direction is
  /// named rather than signed so it reads like `swipe`.
  @override
  Future<JigResponse> adjust(
    JigSelector selector, {
    String direction = 'up',
    int times = 1,
  }) {
    return call('ext.jig.tap', <String, String>{
      ..._selectorArgs(selector),
      'action': direction == 'down' ? 'decrease' : 'increase',
      'times': '$times',
    });
  }

  @override
  Future<JigResponse> screenshot({double pixelRatio = 1}) {
    return call('ext.jig.screenshot', <String, String>{
      'pixelRatio': '$pixelRatio',
    });
  }

  @override
  Future<JigResponse> wait(
    JigSelector selector, {
    bool present = true,
    Duration timeout = const Duration(seconds: 10),
  }) {
    return call('ext.jig.wait', <String, String>{
      ..._selectorArgs(selector),
      'kind': present ? 'present' : 'absent',
      'timeoutMs': '${timeout.inMilliseconds}',
    });
  }

  @override
  Future<JigResponse> events({
    int since = 0,
    Set<JigSource>? sources,
    int limit = 100,
  }) {
    return call('ext.jig.events', <String, String>{
      'since': '$since',
      'limit': '$limit',
      if (sources != null && sources.isNotEmpty)
        'sources': sources.map((source) => source.name).join(','),
    });
  }

  @override
  Future<JigResponse> state({Iterable<String>? names}) {
    return call('ext.jig.state', <String, String>{
      if (names != null && names.isNotEmpty) 'names': names.join(','),
    });
  }

  @override
  Future<JigResponse> nav() => call('ext.jig.nav');

  @override
  Future<JigResponse> back() => call('ext.jig.back');

  @override
  Future<JigResponse> scroll(
    JigSelector selector, {
    bool horizontal = false,
    int steps = 20,
    String? within,
  }) {
    return call('ext.jig.scroll', <String, String>{
      ..._selectorArgs(selector),
      'axis': horizontal ? 'horizontal' : 'vertical',
      'steps': '$steps',
      'in': ?within,
    });
  }

  @override
  Future<JigResponse> ping() => call('ext.jig.ping');

  /// Evaluates Dart source against the app's root library.
  ///
  /// This is the escape hatch for questions no one registered a reader for. It
  /// only works in debug builds, needs the identifiers to be in scope in the root
  /// library, and fails on some generic instantiations - so callers should treat
  /// a failure as "ask for a registered reader" rather than as an app bug.
  Future<JigEvalResult> evaluate(String expression) async {
    final libraryId = _rootLibraryId;
    if (libraryId == null) {
      return const JigEvalResult(
        ok: false,
        error: 'the isolate has no root library',
      );
    }
    try {
      final result = await _service.evaluate(
        _isolateId,
        libraryId,
        expression,
      );
      if (result is vm.ErrorRef) {
        return JigEvalResult(
          ok: false,
          error: result.message ?? 'evaluation failed',
        );
      }
      if (result is vm.InstanceRef) {
        return JigEvalResult(
          ok: true,
          value: result.valueAsString ?? result.valueAsStringIsTruncated,
          kind: result.kind,
        );
      }
      return JigEvalResult(
        ok: true,
        kind: result is vm.Sentinel ? 'sentinel' : null,
      );
    } on vm.RPCError catch (error) {
      return JigEvalResult(ok: false, error: error.message);
    }
  }

  /// Polls [evaluate] until it produces `true`, or the timeout expires.
  ///
  /// Element waits belong in the app (see [wait]); this exists for predicates
  /// about state that has no widget to hang off.
  Future<bool> waitForExpression(
    String expression, {
    Duration timeout = const Duration(seconds: 10),
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final result = await evaluate(expression);
      if (result.ok && result.value == 'true') {
        return true;
      }
      await Future<void>.delayed(interval);
    }
    return false;
  }

  static Map<String, String> _selectorArgs(JigSelector selector) {
    return switch (selector.kind) {
      SelectorKind.semantic => <String, String>{
          'semantic': selector.value,
          if (!selector.exact) 'exact': 'false',
        },
      SelectorKind.key => <String, String>{'key': selector.value},
      SelectorKind.widgetType => <String, String>{
          'type': selector.value,
          'index': '${selector.index}',
        },
      SelectorKind.text => <String, String>{'text': selector.value},
    };
  }
}
