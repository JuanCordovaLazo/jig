/// Transport and verbs for talking to a running Flutter app.
///
/// Kept separate from `jig_cli` so the CLI and the MCP server share one
/// implementation instead of one wrapping the other's stdout.
library;

export 'src/connection.dart';
export 'src/verbs.dart';
