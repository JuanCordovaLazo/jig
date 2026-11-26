/// The wire contract shared by every jig frontend.
///
/// Everything the agent sees crosses this boundary, so the shapes here are the
/// public API of the project: additive changes are minor, anything else is
/// major. See `docs/CONTRACT.md`.
library;

export 'src/element.dart';
export 'src/error.dart';
export 'src/event.dart';
export 'src/rect.dart';
export 'src/response.dart';
export 'src/selector.dart';
export 'src/state_entry.dart';

/// Protocol version reported by `jig version` and by the `ext.jig.ping`
/// extension, so a mismatched CLI can refuse to guess.
const String jigProtocolVersion = '0.1';
