// Rewrites the release version constant from the pubspec, then stages it.
//
// The constant is the single value every frontend reports, so it must equal the
// version of the package that owns it. Keeping the two in step by hand is the kind
// of edit that survives one release and rots the next; `melos version` runs this
// from its `preCommit` hook, when the pubspec has already moved and the release
// commit has not been made.
//
// It stages the file itself: melos only stages the files it wrote, so a change made
// here would otherwise be left out of the release commit.
import 'dart:io';

const String _pubspec = 'packages/jig_protocol/pubspec.yaml';
const String _source = 'packages/jig_protocol/lib/jig_protocol.dart';

void main() {
  final Directory root = _repoRoot();
  final String version = _declaredVersion(File('${root.path}/$_pubspec'));
  final File source = File('${root.path}/$_source');
  final RegExp declaration = RegExp(r"const String jigVersion = '[^']*';");

  final String before = source.readAsStringSync();
  if (!declaration.hasMatch(before)) {
    stderr.writeln('stamp_version: no jigVersion declaration in $_source');
    exit(1);
  }
  final String after = before.replaceFirst(
    declaration,
    "const String jigVersion = '$version';",
  );
  if (after != before) {
    source.writeAsStringSync(after);
  }

  final ProcessResult add = Process.runSync('git', <String>[
    'add',
    _source,
  ], workingDirectory: root.path);
  if (add.exitCode != 0) {
    stderr.writeln('stamp_version: git add failed: ${add.stderr}');
    exit(1);
  }
  stdout.writeln('stamp_version: jigVersion = $version');
}

Directory _repoRoot() {
  final ProcessResult result = Process.runSync('git', <String>[
    'rev-parse',
    '--show-toplevel',
  ]);
  final String path = (result.stdout as String).trim();
  if (result.exitCode != 0 || path.isEmpty) {
    stderr.writeln('stamp_version: not inside a git repository');
    exit(1);
  }
  return Directory(path);
}

String _declaredVersion(File pubspec) {
  final RegExpMatch? match = RegExp(
    r'^version:\s*(\S+)',
    multiLine: true,
  ).firstMatch(pubspec.readAsStringSync());
  final String? version = match?.group(1);
  if (version == null) {
    stderr.writeln('stamp_version: no version in ${pubspec.path}');
    exit(1);
  }
  return version;
}
