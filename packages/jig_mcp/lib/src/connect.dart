import 'dart:io';

import 'package:jig_cli/jig_cli.dart';

/// The VM service URI the server should use, or null when there is none.
///
/// The precedence is the CLI's, deliberately: this is the same connection choice made
/// from a different entry point, and two clients that disagree about which URI wins
/// are two clients that disagree about what they are testing.
///
/// `$JIG_URI` is in the chain because a portable MCP configuration cannot prompt for a
/// value - `inputs` belongs to the editor-managed format, not to `.mcp.json` - so the
/// environment is the only way a client can hand over a URI that changes on every
/// launch.
String? resolveServerUri({
  String? flag,
  Map<String, String>? environment,
  Directory? from,
}) {
  if (flag != null && flag.isNotEmpty) {
    return flag;
  }

  final fromEnvironment = (environment ?? Platform.environment)['JIG_URI'];
  if (fromEnvironment != null && fromEnvironment.isNotEmpty) {
    return fromEnvironment;
  }

  final file = JigSession.discover(from: from);
  if (file == null) {
    return null;
  }
  return JigSession.read(file)?.uri;
}
