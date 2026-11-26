import 'package:jig_protocol/jig_protocol.dart';

/// The verb set, without the transport.
///
/// Declared so an orchestrator can be tested against a fake instead of a device.
/// Only a runner that works over a fake can have its success path verified at all,
/// and a runner whose success path is unverified is one nobody should trust.
///
/// [JigConnection] is the real implementation; nothing else needs to be.
abstract interface class JigVerbs {
  Future<JigResponse> ping();

  Future<JigResponse> tree({
    bool interactiveOnly,
    int limit,
    String? query,
  });

  Future<JigResponse> tap(JigSelector selector, {bool long});

  Future<JigResponse> tapRef(String ref);

  Future<JigResponse> swipe(
    JigSelector selector, {
    String direction,
    String? ref,
  });

  Future<JigResponse> typeText(JigSelector selector, String value);

  Future<JigResponse> clear(JigSelector selector);

  Future<JigResponse> adjust(
    JigSelector selector, {
    String direction,
    int times,
  });

  Future<JigResponse> screenshot({double pixelRatio});

  Future<JigResponse> wait(
    JigSelector selector, {
    bool present,
    Duration timeout,
  });

  Future<JigResponse> scroll(
    JigSelector selector, {
    bool horizontal,
    int steps,
    String? within,
  });

  Future<JigResponse> state({Iterable<String>? names});

  Future<JigResponse> events({
    int since,
    Set<JigSource>? sources,
    int limit,
  });

  Future<JigResponse> nav();

  Future<JigResponse> back();
}
