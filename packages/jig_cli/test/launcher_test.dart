import 'dart:io';

import 'package:jig_cli/jig_cli.dart';
import 'package:test/test.dart';

/// A pinned project must be built with the SDK it pins.
///
/// The selection is worth a test because it is invisible until it is wrong: a global
/// `flutter` builds the app happily, with a version the project does not describe.
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('jig_fvm_');
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  test('an unpinned project runs flutter directly', () {
    final command = JigLauncher.flutterCommand(root);

    expect(command.executable, 'flutter');
    expect(command.arguments, isEmpty);
  });

  test('a .fvmrc pin selects fvm', () {
    File('${root.path}/.fvmrc').writeAsStringSync('{"flutter":"3.47.7"}');

    final command = JigLauncher.flutterCommand(root);

    expect(command.executable, 'fvm');
    expect(command.arguments, <String>['flutter']);
  });

  test('an .fvm directory selects fvm even without .fvmrc', () {
    Directory('${root.path}/.fvm').createSync();

    expect(JigLauncher.flutterCommand(root).executable, 'fvm');
  });

  test('a pin above the working directory still applies', () {
    File('${root.path}/.fvmrc').writeAsStringSync('{"flutter":"3.47.7"}');
    final app = Directory('${root.path}/apps/fixture')
      ..createSync(recursive: true);

    // A repository-wide pin governs the apps under it, which is FVM's own rule.
    expect(JigLauncher.flutterCommand(app).executable, 'fvm');
  });
}
