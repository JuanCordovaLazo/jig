import 'dart:convert';

/// A JSON-RPC 2.0 message, as MCP sends it over stdio.
///
/// Hand-rolled rather than pulled in: MCP over stdio is newline-delimited JSON-RPC,
/// and this tool runs inside other people's editors, so its dependency surface stays
/// at zero.
final class JigRpcMessage {
  const JigRpcMessage({
    required this.method,
    this.id,
    this.params = const <String, Object?>{},
  });

  /// Null for a notification, which is never answered.
  final Object? id;
  final String method;
  final Map<String, Object?> params;

  bool get isNotification => id == null;

  /// Parses one line, or null when it is not a message we can answer.
  static JigRpcMessage? parse(String line) {
    if (line.trim().isEmpty) {
      return null;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) {
      return null;
    }
    final method = decoded['method'];
    if (method is! String) {
      return null;
    }
    final params = decoded['params'];
    return JigRpcMessage(
      id: decoded['id'],
      method: method,
      params: params is Map<String, Object?> ? params : const <String, Object?>{},
    );
  }

  static Map<String, Object?> result(Object? id, Map<String, Object?> result) =>
      <String, Object?>{'jsonrpc': '2.0', 'id': id, 'result': result};

  /// A protocol-level failure: the request was wrong, not the app.
  static Map<String, Object?> error(
    Object? id,
    int code,
    String message, {
    Map<String, Object?>? data,
  }) => <String, Object?>{
    'jsonrpc': '2.0',
    'id': id,
    'error': <String, Object?>{
      'code': code,
      'message': message,
      'data': ?data,
    },
  };
}

/// The JSON-RPC codes this server uses.
abstract final class JigRpcCode {
  static const int methodNotFound = -32601;
  static const int invalidParams = -32602;
  static const int internal = -32603;
}
