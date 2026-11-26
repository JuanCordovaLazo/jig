import 'error.dart';

/// The single envelope every command returns.
///
/// [seq] is the bus sequence at the moment the command finished, so a caller can
/// chain `jig tap ... ` then `jig events --since <seq>` and see exactly what the
/// action caused.
final class JigResponse {
  const JigResponse.ok(this.data, {this.seq = 0, this.elapsedMs = 0})
      : error = null;

  const JigResponse.failure(this.error, {this.seq = 0, this.elapsedMs = 0})
      : data = null;

  final Map<String, Object?>? data;
  final JigError? error;
  final int seq;
  final int elapsedMs;

  bool get ok => error == null;

  Map<String, Object?> toJson() => ok
      ? <String, Object?>{
          'ok': true,
          'data': data,
          'seq': seq,
          'elapsedMs': elapsedMs,
        }
      : <String, Object?>{
          'ok': false,
          'error': error!.toJson(),
          'seq': seq,
          'elapsedMs': elapsedMs,
        };

  static JigResponse fromJson(Map<String, Object?> json) => json['ok'] == true
      ? JigResponse.ok(
          (json['data'] as Map<Object?, Object?>?)?.cast<String, Object?>(),
          seq: json['seq'] as int? ?? 0,
          elapsedMs: json['elapsedMs'] as int? ?? 0,
        )
      : JigResponse.failure(
          _errorFromJson(
            (json['error'] as Map<Object?, Object?>?)?.cast<String, Object?>() ??
                const <String, Object?>{},
          ),
          seq: json['seq'] as int? ?? 0,
          elapsedMs: json['elapsedMs'] as int? ?? 0,
        );

  static JigError _errorFromJson(Map<String, Object?> json) {
    final wire = json['code'] as String? ?? JigErrorCode.internal.wire;
    final code = JigErrorCode.values.firstWhere(
      (candidate) => candidate.wire == wire,
      orElse: () => JigErrorCode.internal,
    );
    return JigError(
      code,
      json['message'] as String? ?? 'unknown error',
      candidates:
          (json['candidates'] as List<Object?>? ?? const <Object?>[])
              .cast<String>(),
      hint: json['hint'] as String?,
    );
  }

  @override
  String toString() => ok ? 'JigResponse.ok($data)' : 'JigResponse($error)';
}
