import 'package:flutter_test/flutter_test.dart';
import 'package:jig_flutter/jig_flutter.dart';
import 'package:jig_protocol/jig_protocol.dart';

void main() {
  test('sequence numbers are monotonic and since() filters by them', () {
    final bus = JigBus()..postToVmService = false;
    final first = bus.emit(JigSource.log, 'a');
    final second = bus.emit(JigSource.nav, 'b');

    expect(second.seq, greaterThan(first.seq));
    expect(bus.since(first.seq).map((e) => e.kind), <String>['b']);
    expect(
      bus.since(0, sources: <JigSource>{JigSource.log}).map((e) => e.kind),
      <String>['a'],
    );
  });

  test('the oldest events are dropped past capacity, seq keeps counting', () {
    final bus = JigBus(capacity: 2)..postToVmService = false;
    for (var i = 0; i < 5; i++) {
      bus.emit(JigSource.log, 'e$i');
    }
    expect(bus.length, 2);
    expect(bus.seq, 5);
    expect(bus.since(0).map((e) => e.kind), <String>['e3', 'e4']);
  });

  test('since() honours its limit', () {
    final bus = JigBus()..postToVmService = false;
    for (var i = 0; i < 5; i++) {
      bus.emit(JigSource.log, 'e$i');
    }
    expect(bus.since(0, limit: 2), hasLength(2));
  });
}
