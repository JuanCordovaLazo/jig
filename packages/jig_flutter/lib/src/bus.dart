import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;

import 'package:jig_protocol/jig_protocol.dart';

/// In-app ring buffer of everything worth knowing about.
///
/// Sequence numbers are monotonic for the life of the isolate, so a consumer asks
/// for "everything after 412" instead of re-reading the buffer. Dropping the
/// oldest entries is deliberate: a diagnostic that grows without bound becomes
/// the bug.
class JigBus {
  JigBus({this.capacity = 4096});

  /// The bus the service extensions read from. One per isolate.
  static final JigBus instance = JigBus();

  final int capacity;

  final Queue<JigEvent> _events = Queue<JigEvent>();
  final StreamController<JigEvent> _live =
      StreamController<JigEvent>.broadcast();

  int _seq = 0;

  /// Mirrors every event through `developer.postEvent`, for consumers that would
  /// rather subscribe than poll. Best effort: it throws when no debugger is
  /// attached, which is not worth surfacing.
  bool postToVmService = true;

  int get seq => _seq;

  int get length => _events.length;

  Stream<JigEvent> get live => _live.stream;

  JigEvent emit(
    JigSource source,
    String kind, [
    Map<String, Object?> data = const <String, Object?>{},
  ]) {
    final event = JigEvent(
      seq: ++_seq,
      source: source,
      kind: kind,
      atMs: DateTime.now().millisecondsSinceEpoch,
      data: data,
    );
    _events.addLast(event);
    while (_events.length > capacity) {
      _events.removeFirst();
    }
    _live.add(event);
    _mirror(event);
    return event;
  }

  /// Events after [afterSeq], oldest first.
  List<JigEvent> since(
    int afterSeq, {
    Set<JigSource>? sources,
    int limit = 200,
  }) {
    final out = <JigEvent>[];
    for (final event in _events) {
      if (event.seq <= afterSeq) {
        continue;
      }
      if (sources != null && !sources.contains(event.source)) {
        continue;
      }
      out.add(event);
      if (out.length >= limit) {
        break;
      }
    }
    return out;
  }

  void clear() => _events.clear();

  void _mirror(JigEvent event) {
    if (!postToVmService) {
      return;
    }
    try {
      developer.postEvent('jig.${event.source.name}', event.toJson());
    } catch (_) {
      // No debugger attached, or the service is shutting down.
    }
  }
}
