import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:jig_driver/jig_driver.dart';
import 'package:jig_protocol/jig_protocol.dart';

import 'audit.dart';
import 'exporter.dart';
import 'launcher.dart';
import 'recorder.dart';
import 'runner.dart';
import 'scenario.dart';
import 'session_store.dart';

const String _usage = '''
jig - an agent-driven test rig for Flutter

Usage: jig [--uri <ws://...>] <command> [options]

Commands:
  launch        Run `flutter run --machine`, publish the VM service URI
  ping          Check protocol, sequence and registered state readers
  run           Execute a scenario file and report each step
  record        Write a scenario from the verbs the app already ran
  export        Write a scenario as an integration_test Dart file
  audit         Report controls no stable selector can name
  tree          List actionable elements from the semantics tree
  find          Like tree, narrowed by a selector
  tap           Activate an element
  swipe         Drag an element in a named direction
  type          Send text to a field
  clear         Empty a field, and read it back to prove it
  adjust        Move a slider or other range control by steps
  screenshot    Capture the rendered frame as a PNG file
  wait          Block until an element appears or disappears, or a state
                expression becomes true
  state         Read registered state readers
  snapshot      Alias for state
  events        Read what happened since a sequence number
  nav           Read the route history
  back          Leave the route the way the system back button does
  scroll        Page a scrollable until a selector is reachable
  eval          Evaluate a Dart expression against the app
  version       Print versions

Selectors (most stable first): --key, --sem, --type, --text, --ref

Everything prints one JSON envelope on stdout:
  {"ok":true,"data":{...},"seq":412,"elapsedMs":38}
  {"ok":false,"error":{"code":"ELEMENT_NOT_FOUND",...},"seq":412}

Exit codes: 0 ok, 1 command failed, 2 usage error.
''';

final class _UsageException implements Exception {
  const _UsageException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<int> runJig(List<String> arguments) async {
  final parser = _buildParser();

  final ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(_usage);
    return 2;
  }

  if (results['help'] == true) {
    final name = results.command?.name;
    final command = name == null ? null : parser.commands[name];
    stdout.writeln(command == null ? _usage : '${command.usage}\n');
    return 0;
  }

  if (results.command == null) {
    stderr.writeln(_usage);
    return 2;
  }

  final command = results.command!;
  try {
    return await _dispatch(command.name!, command, results);
  } on _UsageException catch (error) {
    stderr.writeln(error.message);
    return 2;
  } on JigConnectionException catch (error) {
    stdout.writeln(
      jsonEncode(
        JigResponse.failure(
          JigError(
            JigErrorCode.notConnected,
            error.message,
            hint: 'jig launch -d <device>',
          ),
        ).toJson(),
      ),
    );
    return 1;
  } finally {
    // Connections are per-invocation; nothing outlives the command.
  }
}

Future<int> _dispatch(
  String name,
  ArgResults command,
  ArgResults results,
) async {
  switch (name) {
    case 'version':
      stdout.writeln(
        jsonEncode(<String, Object?>{
          'ok': true,
          'data': <String, Object?>{
            'protocol': jigProtocolVersion,
            'cli': jigVersion,
          },
        }),
      );
      return 0;

    case 'launch':
      return JigLauncher.launch(
        device: command['device'] as String?,
        target: command['target'] as String?,
        flavor: command['flavor'] as String?,
        dartDefines: (command['define'] as List<String>?) ?? const <String>[],
      );
  }

  // Export is entirely local: it writes a Dart file from a scenario and never talks
  // to the app, so it must run before any connection is attempted.
  if (name == 'export') {
    return _export(command);
  }

  // A malformed scenario is the caller's mistake, so it is reported before dialling:
  // a typo in the file must never be confused with an app that is not running.
  final JigScenario? scenario = name == 'run'
      ? _loadScenario(command)
      : null;

  final connection = await _connect(command, results);

  try {
    switch (name) {
      case 'ping':
        return _print(await connection.ping());

      case 'record':
        final since = _intOption(command, 'since') ?? 0;
        final events = await connection.events(
          since: since,
          sources: <JigSource>{JigSource.custom},
          limit: 500,
        );
        final failure = events.error;
        if (failure != null) {
          return _print(events);
        }
        final raw = events.data?['events'];
        final recorded = JigRecorder.record(
          (raw is List<Object?> ? raw : const <Object?>[])
              .cast<Map<String, Object?>>()
              .map(JigEvent.fromJson)
              .toList(growable: false),
          name: (command['name'] as String?) ?? 'recorded',
        );
        final out = command['out'] as String?;
        if (out == null) {
          // No file: the scenario is the payload, so it can be piped somewhere.
          return _print(JigResponse.ok(recorded.toJson()));
        }
        File(out).writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(recorded.toJson())}\n',
        );
        _print(
          JigResponse.ok(<String, Object?>{
            'file': out,
            'steps': recorded.steps.length,
            'skippedEvents': recorded.skippedEvents,
          }),
        );
        // A recording with nothing in it is not a success: it would produce a file
        // that passes forever without checking anything.
        return recorded.steps.isEmpty ? 1 : 0;

      case 'run':
        final parsed = scenario!;
        final report = await JigRunner.run(connection, parsed);
        // The envelope says the run completed; `data.ok` carries the verdict and the
        // exit code mirrors it, so neither one can disagree with the report.
        _print(JigResponse.ok(report.toJson()));
        return report.ok ? 0 : 1;

      case 'audit':        // Reads the whole listing, not the interactive subset: a node with no
        // action is not selectable, so it cannot be the answer to "what can I not
        // reach". `interactiveOnly: false` also keeps unlabelled but readable
        // controls in the count.
        final listing = await connection.tree(
          interactiveOnly: false,
          limit: _intOption(command, 'limit') ?? 600,
        );
        final data = listing.data;
        if (data == null) {
          return _print(listing);
        }
        final elements = (data['elements']! as List<Object?>)
            .cast<Map<String, Object?>>()
            .map(JigElement.fromJson)
            .toList(growable: false);
        final result = JigAudit.run(elements);
        _print(
          JigResponse.ok(
            result.toJson(),
            seq: listing.seq,
            elapsedMs: listing.elapsedMs,
          ),
        );
        // A report that fails the shell is a report people stop running, so the
        // failure code is opt-in and reuses the documented "command failed" 1.
        if (command['strict'] == true && result.blocks) {
          return 1;
        }
        return 0;

      case 'tree':
        return _print(
          await connection.tree(
            interactiveOnly: command['all'] != true,
            limit: _intOption(command, 'limit') ?? 120,
            query: command['q'] as String?,
          ),
        );

      case 'find':
        return _print(
          await connection.tree(
            interactiveOnly: command['all'] != true,
            limit: _intOption(command, 'limit') ?? 60,
            query: _selectorQuery(command),
          ),
        );

      case 'tap':
        final ref = command['ref'] as String?;
        if (ref != null) {
          return _print(await connection.tapRef(ref));
        }
        return _print(
          await connection.tap(
            _selector(command),
            long: command['long'] == true,
          ),
        );

      case 'swipe':
        final swipeRef = command['ref'] as String?;
        return _print(
          await connection.swipe(
            // A ref replaces the selector, so the selector is only read when there
            // is no ref - otherwise a ref-only call would fail before it started.
            swipeRef != null && swipeRef.isNotEmpty
                ? JigSelector.key(swipeRef)
                : _selector(command),
            direction: command['direction']! as String,
            ref: swipeRef,
          ),
        );

      case 'type':
        final value = command['value'] as String?;
        if (value == null) {
          throw const _UsageException('Missing --value');
        }
        if (value.isEmpty) {
          throw const _UsageException(
            'An empty --value does not clear a field: use `jig clear`, which '
            'reads the field back instead of reporting what it sent.',
          );
        }
        return _print(await connection.typeText(_selector(command), value));

      case 'clear':
        return _print(await connection.clear(_selector(command)));

      case 'adjust':
        return _print(
          await connection.adjust(
            _selector(command),
            direction: command['direction']! as String,
            times: _intOption(command, 'times') ?? 1,
          ),
        );

      case 'screenshot':
        return await _screenshot(connection, command);

      case 'wait':
        final expression = command['state'] as String?;
        if (expression != null && expression.isNotEmpty) {
          return await _waitForState(connection, expression, command);
        }
        return _print(
          await connection.wait(
            _selector(command),
            present: command['absent'] != true,
            timeout: _durationOption(command, 'timeout'),
          ),
        );

      case 'events':
        return _print(
          await connection.events(
            since: _intOption(command, 'since') ?? 0,
            sources: _sourcesOption(command),
            limit: _intOption(command, 'limit') ?? 100,
          ),
        );

      case 'state':
      case 'snapshot':
        return _print(
          await connection.state(names: _csvOption(command, 'names')),
        );

      case 'nav':
        return _print(await connection.nav());

      case 'back':
        return _print(await connection.back());

      case 'scroll':
        return _print(
          await connection.scroll(
            _selector(command),
            horizontal: command['axis'] == 'horizontal',
            steps: _intOption(command, 'steps') ?? 20,
            within: command['in'] as String?,
          ),
        );

      case 'eval':
        final rest = command.rest;
        if (rest.isEmpty) {
          throw const _UsageException('Missing expression');
        }
        final result = await connection.evaluate(rest.join(' '));
        stdout.writeln(
          jsonEncode(
            result.ok
                ? <String, Object?>{'ok': true, 'data': result.toJson()}
                : <String, Object?>{
                    'ok': false,
                    'error': <String, Object?>{
                      'code': JigErrorCode.evalFailed.wire,
                      'message': result.error,
                      'hint': 'Register a reader with Jig.state() instead.',
                    },
                  },
          ),
        );
        return result.ok ? 0 : 1;

      default:
        throw _UsageException('Unknown command: $name');
    }
  } finally {
    await connection.dispose();
  }
}

ArgParser _buildParser() {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption(
      'uri',
      help: 'VM service URI (default: JIG_URI or .jig/session.json)',
    );

  parser.addCommand('version');

  parser.addCommand('launch')
    ..addOption('device', abbr: 'd')
    ..addOption('target', abbr: 't')
    ..addOption('flavor')
    ..addMultiOption('define');

  parser.addCommand('ping');

  parser.addCommand('run').addOption(
    'file',
    abbr: 'f',
    help: 'Scenario file; may also be given as the only argument',
  );

  parser.addCommand('export')
    ..addOption('scenario', abbr: 's', help: 'Scenario file to export')
    ..addOption('out', abbr: 'o', help: 'Dart file to write; stdout when omitted')
    ..addOption(
      'entry',
      abbr: 'e',
      help: 'Import of the app entry point, e.g. package:my_app/main.dart',
    );

  parser.addCommand('record')
    ..addOption('since', help: 'Only events after this sequence number')
    ..addOption('out', abbr: 'o', help: 'File to write; stdout when omitted')
    ..addOption('name', help: 'Scenario name');

  parser.addCommand('audit')
    ..addFlag(
      'strict',
      negatable: false,
      help: 'Exit 1 when a control has no stable selector',
    )
    ..addOption('limit', help: 'How many elements to read');

  _selectorOptions(
    parser.addCommand('tree')
      ..addFlag('all', negatable: false, help: 'Include non-interactive nodes')
      ..addOption('limit')
      ..addOption('q', abbr: 'q', help: 'Filter by key, label or value'),
  );

  _selectorOptions(
    parser.addCommand('find')
      ..addFlag('all', negatable: false)
      ..addOption('limit'),
  );

  _selectorOptions(
    parser.addCommand('tap')
      ..addOption('ref')
      ..addFlag('long', negatable: false),
  );

  _selectorOptions(
    parser.addCommand('swipe')
      ..addOption('ref', help: 'A handle from jig tree, instead of a selector')
      ..addOption(
        'direction',
        allowed: <String>['left', 'right', 'up', 'down'],
        defaultsTo: 'left',
        help: 'Which way the content moves',
      ),
  );

  _selectorOptions(parser.addCommand('type')..addOption('value', abbr: 'v'));

  _selectorOptions(parser.addCommand('clear'));

  _selectorOptions(
    parser.addCommand('adjust')
      ..addOption(
        'direction',
        allowed: <String>['up', 'down'],
        defaultsTo: 'up',
        help: 'Which way the value moves',
      )
      ..addOption('times', help: 'How many steps (default 1)'),
  );

  parser.addCommand('screenshot')
    ..addOption(
      'out',
      abbr: 'o',
      help: 'PNG file to write; default .jig/screenshot-<seq>.png',
    )
    ..addOption(
      'pixel-ratio',
      help: 'Capture scale, in image pixels per logical pixel (default 1)',
    )
    ..addOption('uri');

  _selectorOptions(
    parser.addCommand('wait')
      ..addFlag('absent', negatable: false)
      ..addOption('state', help: 'Dart expression that must evaluate to true')
      ..addOption('timeout'),
  );

  parser.addCommand('events')
    ..addOption('since')
    ..addOption('limit')
    ..addOption('sources');

  parser.addCommand('state').addOption('names');
  parser.addCommand('snapshot').addOption('names');
  parser.addCommand('nav');
  parser.addCommand('back');

  _selectorOptions(
    parser.addCommand('scroll')
      ..addOption(
        'axis',
        allowed: <String>['vertical', 'horizontal'],
        defaultsTo: 'vertical',
      )
      ..addOption('steps', help: 'Maximum pages before giving up')
      ..addOption('in', help: 'Key, type or label of the scrollable to page'),
  );

  parser.addCommand('eval').addOption('uri');

  return parser;
}

ArgParser _selectorOptions(ArgParser parser) => parser
  ..addOption('sem', abbr: 's', help: 'Accessibility label')
  ..addOption('key', abbr: 'k', help: 'Widget key value')
  ..addOption('type', help: 'Widget runtime type')
  ..addOption('text', help: 'Visible text')
  ..addOption('index', help: 'Disambiguate --type')
  ..addFlag('exact', defaultsTo: true, help: 'Label must match exactly')
  ..addOption('uri');

Future<JigConnection> _connect(ArgResults command, ArgResults results) async {
  final explicit = (command.options.contains('uri')
          ? command['uri'] as String?
          : null) ??
      results['uri'] as String? ??
      Platform.environment['JIG_URI'];

  if (explicit != null && explicit.isNotEmpty) {
    return JigConnection.attach(explicit);
  }

  final file = JigSession.discover();
  final session = file == null ? null : JigSession.read(file);
  if (session == null) {
    throw const JigConnectionException(
      'No session. Start one with `jig launch -d <device>`, or pass --uri.',
    );
  }
  return JigConnection.attach(session.uri);
}

/// Polls a Dart expression through the driver.
///
/// This path round-trips on every attempt, so it is the slow way to wait; it
/// exists for predicates that have no element to hang off, such as "step two
/// actually advanced".
Future<int> _waitForState(
  JigConnection connection,
  String expression,
  ArgResults command,
) async {
  final timeout = _durationOption(command, 'timeout');
  final stopwatch = Stopwatch()..start();
  final reached = await connection.waitForExpression(expression, timeout: timeout);
  stopwatch.stop();
  // One round trip for the sequence number, so the envelope still lets a caller
  // chain `events --since` - the case where waiting failed is exactly when that
  // matters.
  final ping = await connection.ping();
  if (!reached) {
    return _print(
      JigResponse.failure(
        JigError(
          JigErrorCode.timeout,
          'Timed out after ${timeout.inSeconds}s waiting for $expression',
          hint: 'jig eval <expression>, or read jig events for what happened',
        ),
        seq: ping.seq,
        elapsedMs: stopwatch.elapsedMilliseconds,
      ),
    );
  }
  return _print(
    JigResponse.ok(
      <String, Object?>{
        'waitedMs': stopwatch.elapsedMilliseconds,
        'expression': expression,
      },
      seq: ping.seq,
      elapsedMs: stopwatch.elapsedMilliseconds,
    ),
  );
}

/// Reads and validates the scenario a `run` command was given.
///
/// Every failure here is a usage error (exit 2): the file is missing, unreadable, or
/// not a scenario. None of them should reach the app, and none should look like one.
JigScenario _loadScenario(ArgResults command) {
  final path =
      (command['file'] as String?) ??
      (command.rest.isEmpty ? null : command.rest.first);
  if (path == null) {
    throw const _UsageException('Missing scenario file');
  }
  final file = File(path);
  if (!file.existsSync()) {
    throw _UsageException('No such scenario: $path');
  }
  try {
    return JigScenario.parse(file.readAsStringSync());
  } on JigScenarioException catch (error) {
    throw _UsageException('$path: $error');
  } on FileSystemException catch (error) {
    throw _UsageException('$path: ${error.message}');
  }
}

/// Writes a scenario as an `integration_test` file.
///
/// Entirely local: no session is involved, so this runs before any connection is
/// attempted. A missing app would otherwise look like a broken scenario.
int _export(ArgResults command) {
  final scenarioPath =
      (command['scenario'] as String?) ??
      (command.rest.isEmpty ? null : command.rest.first);
  if (scenarioPath == null) {
    throw const _UsageException('Missing --scenario <file>');
  }
  final entry = command['entry'] as String?;
  if (entry == null || entry.isEmpty) {
    throw const _UsageException(
      'Missing --entry <package import>, e.g. package:my_app/main.dart',
    );
  }
  final scenarioFile = File(scenarioPath);
  if (!scenarioFile.existsSync()) {
    throw _UsageException('No such scenario: $scenarioPath');
  }
  final JigScenario source;
  try {
    source = JigScenario.parse(scenarioFile.readAsStringSync());
  } on JigScenarioException catch (error) {
    throw _UsageException('$scenarioPath: $error');
  }
  final String generated;
  try {
    generated = JigExporter.export(source, entry: entry);
  } on JigExportException catch (error) {
    throw _UsageException('$scenarioPath: $error');
  }
  final target = command['out'] as String?;
  if (target == null) {
    stdout.write(generated);
    return 0;
  }
  File(target).writeAsStringSync(generated);
  _print(
    JigResponse.ok(<String, Object?>{
      'file': target,
      'scenario': source.name,
      'steps': source.steps.length,
    }),
  );
  return 0;

}

JigSelector _selector(ArgResults command) {
  final semantic = command['sem'] as String?;
  if (semantic != null && semantic.isNotEmpty) {
    return JigSelector.semantic(semantic, exact: command['exact'] != false);
  }
  final key = command['key'] as String?;
  if (key != null && key.isNotEmpty) {
    return JigSelector.key(key);
  }
  final type = command['type'] as String?;
  if (type != null && type.isNotEmpty) {
    return JigSelector.widgetType(
      type,
      index: _intOption(command, 'index') ?? 0,
    );
  }
  final text = command['text'] as String?;
  if (text != null && text.isNotEmpty) {
    return JigSelector.text(text);
  }
  throw const _UsageException(
    'Provide one of --sem, --key, --type or --text',
  );
}

String? _selectorQuery(ArgResults command) {
  for (final name in const <String>['sem', 'text', 'key', 'type']) {
    final value = command.options.contains(name) ? command[name] as String? : null;
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

int? _intOption(ArgResults command, String name) {
  if (!command.options.contains(name)) {
    return null;
  }
  return int.tryParse(command[name] as String? ?? '');
}

/// Captures the frame and writes it where a caller can open it.
///
/// The bytes are not put in the envelope: a megabyte of base64 on a shell's stdout
/// is unreadable and unpipable, while a path is both. The MCP tool keeps the bytes,
/// because there the client renders them.
Future<int> _screenshot(JigConnection connection, ArgResults command) async {
  final raw = command['pixel-ratio'] as String?;
  final ratio = raw == null || raw.isEmpty ? 1.0 : double.tryParse(raw);
  if (ratio == null || !ratio.isFinite || ratio <= 0) {
    throw _UsageException('--pixel-ratio must be a positive number, not "$raw"');
  }

  final response = await connection.screenshot(pixelRatio: ratio);
  final data = response.data;
  final encoded = data?['base64'];
  if (response.error != null || data == null || encoded is! String) {
    return _print(response);
  }

  final bytes = base64Decode(encoded);
  final file = (command['out'] as String?) ?? _screenshotPath(response.seq);
  File(file)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(bytes);

  // Everything the caller needs to open or assert on the file, and nothing they
  // would have to decode first.
  _print(
    JigResponse.ok(<String, Object?>{
      'file': file,
      'format': data['format'],
      'width': data['width'],
      'height': data['height'],
      'bytes': bytes.length,
      'pixelRatio': data['pixelRatio'],
    }, seq: response.seq, elapsedMs: response.elapsedMs),
  );
  return 0;
}

/// Where a capture goes when the caller did not name a file.
///
/// Beside the session file, so it lands in the `.jig/` directory jig already owns
/// and already ignores; the working directory is left alone.
String _screenshotPath(int seq) {
  final session = JigSession.discover();
  final directory = session == null
      ? '${Directory.current.path}${Platform.pathSeparator}'
            '${JigSession.directory}'
      : session.parent.path;
  return '$directory${Platform.pathSeparator}screenshot-$seq.png';
}

Duration _durationOption(ArgResults command, String name) {
  final raw = command.options.contains(name) ? command[name] as String? : null;
  if (raw == null || raw.isEmpty) {
    return const Duration(seconds: 10);
  }
  final seconds = int.tryParse(raw.replaceAll(RegExp('[^0-9]'), ''));
  return Duration(seconds: seconds ?? 10);
}

Set<JigSource>? _sourcesOption(ArgResults command) {
  final raw = command['sources'] as String?;
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return raw
      .split(',')
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .map(
        (name) => JigSource.values.firstWhere(
          (source) => source.name == name,
          orElse: () => JigSource.custom,
        ),
      )
      .toSet();
}

Iterable<String>? _csvOption(ArgResults command, String name) {
  final raw = command.options.contains(name) ? command[name] as String? : null;
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return raw
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty);
}

int _print(JigResponse response) {
  stdout.writeln(jsonEncode(response.toJson()));
  return response.ok ? 0 : 1;
}
