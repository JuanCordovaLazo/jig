import 'dart:convert';
import 'dart:io';

/// Where `jig launch` publishes the VM service URI, so the commands that follow
/// do not need the caller to carry a `ws://` string around.
final class JigSession {
  const JigSession({
    required this.uri,
    required this.startedAt,
    this.pid,
    this.target,
  });

  final String uri;
  final String startedAt;
  final int? pid;
  final String? target;

  static const String directory = '.jig';
  static const String fileName = 'session.json';

  Map<String, Object?> toJson() => <String, Object?>{
        'uri': uri,
        'startedAt': startedAt,
        if (pid != null) 'pid': pid,
        if (target != null) 'target': target,
      };

  /// The session file a project root would contain. `directory` is the folder
  /// name (`.jig`), so callers pass a project root, not the folder itself.
  static File fileFor(Directory projectRoot) => File(
        '${projectRoot.path}${Platform.pathSeparator}'
        '$directory${Platform.pathSeparator}$fileName',
      );

  static File fileIn(Directory directory) =>
      File('${directory.path}${Platform.pathSeparator}$fileName');

  /// Walks up from [from] looking for the nearest session file.
  static File? discover({Directory? from}) {
    var current = from ?? Directory.current;
    for (var depth = 0; depth < 6; depth++) {
      final candidate = fileFor(current);
      if (candidate.existsSync()) {
        return candidate;
      }
      final parent = current.parent;
      if (parent.path == current.path) {
        break;
      }
      current = parent;
    }
    return null;
  }

  static JigSession? read(File file) {
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      final uri = decoded['uri'];
      if (uri is! String || uri.isEmpty) {
        return null;
      }
      return JigSession(
        uri: uri,
        startedAt: decoded['startedAt'] as String? ?? '',
        pid: decoded['pid'] as int?,
        target: decoded['target'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  void write(File file) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(toJson()),
    );
  }
}
