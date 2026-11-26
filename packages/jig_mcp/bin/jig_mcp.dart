import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:jig_driver/jig_driver.dart';
import 'package:jig_mcp/jig_mcp.dart';

/// MCP over stdio: one JSON-RPC message per line in, one per line out.
///
/// The stdio loop starts before anything connects, and that ordering is the whole
/// point. A client sends `initialize` and waits on its own deadline; if the connect
/// comes first, a stale session file pointing at a host that never answers makes the
/// server look dead - measured at 134 seconds, long past any client's patience, and
/// the client's report ("never became ready") says nothing about the real cause.
/// Neither `initialize` nor `tools/list` needs the app, so neither waits for it.
Future<void> main(List<String> args) async {
  final initialUri = resolveServerUri(flag: _option(args, '--uri'));

  JigConnection? connection;

  Future<JigVerbs> connectTo(String uri) async {
    final attached = await JigConnection.attach(uri);
    connection = attached;
    return attached;
  }

  final verbs = JigLazyVerbs(() async {
    final uri = initialUri;
    if (uri == null) {
      throw const JigConnectionException(
        'No session. Start one with `jig launch -d <device>`, pass --uri, set '
        'JIG_URI, or call the connect tool with a VM service URI.',
      );
    }
    return connectTo(uri);
  });

  final server = JigMcpServer(verbs, attach: (String uri) async {
    final attached = await connectTo(uri);
    // The tool that established this connection is the same object every other
    // tool will use, so the lazy swap has to happen here rather than in the server:
    // only the bin owns the verbs instance.
    verbs.reconnect(() async => attached);
    return attached;
  });
  final out = stdout;

  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    final message = JigRpcMessage.parse(line);
    if (message == null) {
      continue;
    }
    final Map<String, Object?>? reply;
    try {
      reply = await server.handle(<String, Object?>{
        'id': message.id,
        'method': message.method,
        'params': message.params,
      });
    } catch (error) {
      // The loop is the server. An exception that escapes it ends the process, and
      // a client that loses the pipe mid-session has no way to say why.
      out.writeln(
        jsonEncode(
          JigRpcMessage.error(message.id, JigRpcCode.internal, '$error'),
        ),
      );
      await out.flush();
      continue;
    }
    if (reply == null) {
      continue;
    }
    out.writeln(jsonEncode(reply));
    await out.flush();
  }

  // stdin closed: the client is done. Without this the open WebSocket keeps the
  // isolate alive, so a client that closes the pipe waits for a process that never
  // ends. Exiting is the stdio transport's shutdown signal.
  await connection?.dispose();
  await out.flush();
  exit(0);
}

String? _option(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index < 0 || index + 1 >= args.length) {
    return null;
  }
  return args[index + 1];
}
