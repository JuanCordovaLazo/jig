import 'dart:convert';
import 'dart:io';

import 'session_store.dart';

/// Thin wrapper around `flutter run --machine`.
///
/// This is a foreground command on purpose: `flutter run` owns the app process,
/// and detaching it would orphan the app. It publishes the session file as soon
/// as the VM service URI exists, so other terminals (or an agent) can act while
/// it streams.
final class JigLauncher {
  static Future<int> launch({
    String? device,
    String? target,
    String? flavor,
    List<String> dartDefines = const <String>[],
    Directory? workingDirectory,
  }) async {
    final workdir = workingDirectory ?? Directory.current;

    // `flutter run` resolves its target relative to the working directory, so running
    // this from a monorepo root fails inside Flutter with "Target file lib/main.dart
    // not found" - a message about Flutter's default, not about the mistake. Naming
    // the actual problem costs one file check and saves the caller from guessing.
    if (target == null &&
        !File('${workdir.path}${Platform.pathSeparator}lib'
                '${Platform.pathSeparator}main.dart')
            .existsSync()) {
      stderr.writeln(
        'No lib/main.dart under ${workdir.path}, and no -t/--target given.',
      );
      stderr.writeln(
        'Run launch from the app directory, or name the entry point:',
      );
      stderr.writeln('  jig launch -d <device> -t lib/main.dart');
      return 2;
    }

    final flutter = flutterCommand(workdir);

    final arguments = <String>[
      ...flutter.arguments,
      'run',
      '--machine',
      if (device != null) ...<String>['-d', device],
      if (target != null) ...<String>['-t', target],
      if (flavor != null) ...<String>['--flavor', flavor],
      for (final define in dartDefines) '--dart-define=$define',
    ];

    final process = await Process.start(
      flutter.executable,
      arguments,
      workingDirectory: workdir.path,
    );

    final sessionFile = JigSession.fileFor(workdir);

    var published = false;

    void publish(Map<String, Object?> params) {
      final wsUri = params['wsUri'];
      if (published || wsUri is! String || wsUri.isEmpty) {
        return;
      }
      published = true;
      final session = JigSession(
        uri: wsUri,
        startedAt: DateTime.now().toIso8601String(),
        pid: process.pid,
        target: target,
      );
      session.write(sessionFile);
      stdout.writeln(
        jsonEncode(<String, Object?>{
          'ok': true,
          'event': 'jig.launch',
          'data': <String, Object?>{
            'uri': wsUri,
            'session': sessionFile.path,
            'pid': process.pid,
          },
        }),
      );
    }

    final stdoutDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      for (final message in _decode(line)) {
        final event = message['event'];
        final params = message['params'];
        if (params is Map<String, Object?>) {
          if (event == 'app.debugPort' || event == 'app.started') {
            publish(params);
          }
          if (event == 'app.stop') {
            stdout.writeln(
              jsonEncode(<String, Object?>{'ok': false, 'event': 'jig.stop'}),
            );
          }
        }
      }
    }).asFuture<void>();

    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(stderr.writeln)
        .asFuture<void>();

    final exitCode = await process.exitCode;
    await Future.wait(<Future<void>>[stdoutDone, stderrDone]);

    if (sessionFile.existsSync()) {
      sessionFile.deleteSync();
    }
    return exitCode;
  }

  /// `--machine` writes a JSON array per line in some versions and a bare object
  /// in others; accepting both avoids a version sniff.
  static List<Map<String, Object?>> _decode(String line) {
    if (line.trim().isEmpty) {
      return const <Map<String, Object?>>[];
    }
    try {
      final decoded = jsonDecode(line);
      if (decoded is Map<String, Object?>) {
        return <Map<String, Object?>>[decoded];
      }
      if (decoded is List<Object?>) {
        return decoded.whereType<Map<String, Object?>>().toList();
      }
    } catch (_) {
      // Non-protocol output (warnings, progress). Ignored on purpose.
    }
    return const <Map<String, Object?>>[];
  }

  /// Honours FVM when the project pins a Flutter version.
  /// The `flutter` to run, honouring an FVM pin.
  ///
  /// A pinned project has to be built with the SDK it pins, and `fvm` is how that SDK
  /// gets selected; running the global `flutter` instead builds the app with a version
  /// its own configuration does not describe. The search walks up because a pin at the
  /// repository root governs the apps under it, which is the rule FVM itself applies.
  static ({String executable, List<String> arguments}) flutterCommand(
    Directory directory,
  ) {
    return _isPinned(directory)
        ? (executable: 'fvm', arguments: <String>['flutter'])
        : (executable: 'flutter', arguments: const <String>[]);
  }

  static bool _isPinned(Directory directory) {
    var current = directory.absolute;
    for (var depth = 0; depth < 6; depth++) {
      if (File('${current.path}/.fvmrc').existsSync() ||
          Directory('${current.path}/.fvm').existsSync()) {
        return true;
      }
      final parent = current.parent;
      if (parent.path == current.path) {
        return false;
      }
      current = parent;
    }
    return false;
  }
}
