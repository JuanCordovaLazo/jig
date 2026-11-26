import 'package:flutter_test/flutter_test.dart';
import 'package:jig_fixture/controllers.dart';
import 'package:jig_fixture/fake_backend.dart';
import 'package:jig_flutter/jig_flutter.dart';
import 'package:jig_protocol/jig_protocol.dart';

/// Rows 6 and 7 need a real socket, so these are plain `test`s and not
/// `testWidgets`: `TestWidgetsFlutterBinding` installs an `HttpOverrides` that
/// answers every request with a 400 and never opens a connection, so a widget test
/// can only ever observe that mock. Nothing here needs a frame anyway - the rows
/// are about what leaves the call, not about what is on screen.
void main() {
  setUp(JigNavHistory.clear);

  test('a transport failure reaches the event bus as an error', () async {
    final backend = await FakeBackend.start();
    final bus = JigBus.instance;
    final start = bus.seq;
    final api = ApiController(backend.base);

    try {
      // `/slow` outlives the client timeout. GetConnect surfaces that as a
      // response with no body and no status rather than an exception, so a
      // tracing layer that only hooks response modifiers would see a success and
      // report nothing at all.
      await api.loadSlow();

      final events = bus.since(start, sources: <JigSource>{JigSource.http});
      expect(events.any((JigEvent event) => event.kind == 'error'), isTrue);
      expect(events.any((JigEvent event) => event.kind == 'response'), isFalse);

      // Pinned on purpose: no status is the same shape a 200-shaped lie would
      // not have. If this ever reads a code, the tracing has started trusting a
      // response that never arrived.
      expect(api.lastStatus.value, 'slow: null');
    } finally {
      await backend.stop();
    }
  });

  test('the authenticator retry reports the 200 and never the 401', () async {
    final backend = await FakeBackend.start();
    final bus = JigBus.instance;
    final start = bus.seq;
    final api = ApiController(backend.base);

    try {
      await api.loadSecure();
      expect(api.lastStatus.value, 'secure: 200');

      final events = bus.since(start, sources: <JigSource>{JigSource.http})
          .toList(growable: false);

      expect(
        events.any(
          (JigEvent event) =>
              event.kind == 'response' && event.data['status'] == 200,
        ),
        isTrue,
      );
      // The 401 is retried inside the call, so it must never surface as its own
      // exchange: seeing one would mean the harness reported an intermediate
      // state as the outcome.
      expect(
        events.any((JigEvent event) => event.data['status'] == 401),
        isFalse,
      );
      expect(
        events.where((JigEvent event) => event.kind == 'request'),
        hasLength(1),
      );
    } finally {
      await backend.stop();
    }
  });
}
