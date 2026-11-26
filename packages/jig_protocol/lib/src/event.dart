enum JigSource { http, log, nav, error, state, custom }

/// One thing that happened inside the app, addressable by a monotonic [seq].
final class JigEvent {
  const JigEvent({
    required this.seq,
    required this.source,
    required this.kind,
    required this.atMs,
    this.data = const <String, Object?>{},
  });

  final int seq;
  final JigSource source;
  final String kind;
  final int atMs;
  final Map<String, Object?> data;

  Map<String, Object?> toJson() => <String, Object?>{
        'seq': seq,
        'source': source.name,
        'kind': kind,
        'at': atMs,
        if (data.isNotEmpty) 'data': data,
      };

  static JigEvent fromJson(Map<String, Object?> json) => JigEvent(
        seq: json['seq']! as int,
        source: JigSource.values.byName(json['source']! as String),
        kind: json['kind']! as String,
        atMs: json['at'] as int? ?? 0,
        data: (json['data'] as Map<Object?, Object?>? ?? const <Object?, Object?>{})
            .cast<String, Object?>(),
      );

  @override
  String toString() => '$seq ${source.name}.$kind $data';
}
