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
///
/// Moves only when a wire change breaks existing consumers; an additive change
/// keeps it and takes a minor package bump. See `docs/CONTRACT.md`.
const String jigProtocolVersion = '1';

/// The version of the jig package set. Every package shares it, so a frontend
/// reports one number for the whole release. Rewritten by
/// `tool/stamp_version.dart` from `packages/jig_protocol/pubspec.yaml`.
const String jigVersion = '1.0.0';
