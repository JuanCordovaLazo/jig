import 'dart:io';

import 'package:jig_cli/jig_cli.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runJig(arguments);
}
