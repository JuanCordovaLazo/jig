import 'dart:async';

import 'package:jig_driver/jig_driver.dart';
import 'package:jig_protocol/jig_protocol.dart';

/// Verbs whose connection is made on first use instead of at startup.
///
/// An MCP server has a handshake deadline it does not control: the client sends
/// `initialize` and waits. Connecting first is what makes a server look dead - a
/// stale session file pointing at a host that never answers held this one for 134
/// seconds, and every client gave up before the reply arrived. Nothing in
/// `initialize` or `tools/list` needs the app, so nothing there should wait for it.
///
/// A failed connect is not cached, because the reason for it is usually temporary:
/// the app is still starting, or the user relaunches it without restarting the
/// editor. Success is cached, because a live connection is meant to be reused.
final class JigLazyVerbs implements JigVerbs {
  JigLazyVerbs(this._connect, {this.onConnect});

  /// Builds a connection. Throwing is how it reports that it cannot.
  Future<JigVerbs> Function() _connect;

  /// Called once per successful connect, so a transport can keep the handle it has
  /// to dispose at shutdown.
  final void Function(JigVerbs verbs)? onConnect;

  Future<JigVerbs>? _pending;
  JigVerbs? _resolved;

  /// The live verbs, or null while nothing has connected yet.
  JigVerbs? get resolved => _resolved;

  bool get isConnected => _resolved != null;

  /// Points the lazy verbs at a new connection, dropping the old one.
  ///
  /// Lets a client supply a URI after startup, which is the only way to use an MCP
  /// server whose working directory is not the one `jig launch` wrote to.
  void reconnect(Future<JigVerbs> Function() connect) {
    _connect = connect;
    _resolved = null;
    _pending = null;
  }

  Future<JigVerbs> _verbs() async {
    final ready = _resolved;
    if (ready != null) {
      return ready;
    }
    final pending = _pending ??= _connect();
    try {
      final verbs = await pending;
      _resolved = verbs;
      onConnect?.call(verbs);
      return verbs;
    } catch (_) {
      _pending = null;
      rethrow;
    }
  }

  /// Runs [operation] against the live verbs, turning a connect failure into the
  /// `NOT_CONNECTED` answer a caller can act on.
  ///
  /// A tool that reported a JSON-RPC error here would be claiming the server is
  /// broken; it is the app that is missing, and the envelope already says so.
  Future<JigResponse> _run(
    Future<JigResponse> Function(JigVerbs verbs) operation,
  ) async {
    final JigVerbs verbs;
    try {
      verbs = await _verbs();
    } on JigConnectionException catch (error) {
      return JigResponse.failure(
        JigError(
          JigErrorCode.notConnected,
          error.message,
          hint: 'jig launch -d <device>',
        ),
      );
    }
    return operation(verbs);
  }

  @override
  Future<JigResponse> ping() => _run((JigVerbs v) => v.ping());

  @override
  Future<JigResponse> tree({
    bool interactiveOnly = true,
    int limit = 120,
    String? query,
  }) => _run(
    (JigVerbs v) => v.tree(
      interactiveOnly: interactiveOnly,
      limit: limit,
      query: query,
    ),
  );

  @override
  Future<JigResponse> tap(JigSelector selector, {bool long = false}) =>
      _run((JigVerbs v) => v.tap(selector, long: long));

  @override
  Future<JigResponse> tapRef(String ref) => _run((JigVerbs v) => v.tapRef(ref));

  @override
  Future<JigResponse> swipe(
    JigSelector selector, {
    String direction = 'left',
    String? ref,
  }) => _run(
    (JigVerbs v) => v.swipe(selector, direction: direction, ref: ref),
  );

  @override
  Future<JigResponse> typeText(JigSelector selector, String value) =>
      _run((JigVerbs v) => v.typeText(selector, value));

  @override
  Future<JigResponse> clear(JigSelector selector) =>
      _run((JigVerbs v) => v.clear(selector));

  @override
  Future<JigResponse> adjust(
    JigSelector selector, {
    String direction = 'up',
    int times = 1,
  }) => _run(
    (JigVerbs v) => v.adjust(selector, direction: direction, times: times),
  );

  @override
  Future<JigResponse> screenshot({double pixelRatio = 1}) =>
      _run((JigVerbs v) => v.screenshot(pixelRatio: pixelRatio));

  @override
  Future<JigResponse> wait(
    JigSelector selector, {
    bool present = true,
    Duration timeout = const Duration(seconds: 10),
  }) => _run(
    (JigVerbs v) => v.wait(selector, present: present, timeout: timeout),
  );

  @override
  Future<JigResponse> scroll(
    JigSelector selector, {
    bool horizontal = false,
    int steps = 20,
    String? within,
  }) => _run(
    (JigVerbs v) => v.scroll(
      selector,
      horizontal: horizontal,
      steps: steps,
      within: within,
    ),
  );

  @override
  Future<JigResponse> state({Iterable<String>? names}) =>
      _run((JigVerbs v) => v.state(names: names));

  @override
  Future<JigResponse> events({
    int since = 0,
    Set<JigSource>? sources,
    int limit = 100,
  }) => _run((JigVerbs v) => v.events(since: since, sources: sources, limit: limit));

  @override
  Future<JigResponse> nav() => _run((JigVerbs v) => v.nav());

  @override
  Future<JigResponse> back() => _run((JigVerbs v) => v.back());
}
