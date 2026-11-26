import 'dart:convert';

import 'package:jig_cli/jig_cli.dart';
import 'package:jig_driver/jig_driver.dart';
import 'package:jig_protocol/jig_protocol.dart';

import 'rpc.dart';

/// Raised when a tool was called with arguments it cannot use.
///
/// Local on purpose: the app-side `JigActionFailure` lives in `jig_flutter`, and this
/// package must not depend on Flutter. A caller mistake is a JSON-RPC invalid-params,
/// not a tool failure, so it travels a different path from an app error.
final class JigArgumentException implements Exception {
  const JigArgumentException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One tool the server offers, with the JSON schema a client needs to call it.
final class JigTool {
  const JigTool({
    required this.name,
    required this.description,
    this.schema = const <String, Object?>{'type': 'object'},
    this.handler,
    this.standalone,
    this.image = false,
  });

  final String name;
  final String description;
  final Map<String, Object?> schema;

  /// Runs the tool. Null for a tool that is served by [standalone] instead.
  final Future<JigResponse> Function(JigVerbs verbs, Map<String, Object?> args)?
  handler;

  /// Runs the tool without verbs, for the one tool that exists to change which
  /// verbs the server has. Everything it does is transport, and the transport is
  /// what the verbs cannot describe.
  final Future<JigResponse> Function(Map<String, Object?> args)? standalone;

  /// Whether a successful result is an image the client renders, rather than JSON.
  final bool image;
}

/// A Model Context Protocol server over jig's verbs.
///
/// Deliberately transport-free: [handle] takes a parsed message and returns the reply,
/// so the whole protocol layer is testable by feeding it maps. Only the stdio entry
/// point knows about a socket.
final class JigMcpServer {
  JigMcpServer(
    this.verbs, {
    this.protocolVersion = '2024-11-05',
    this.attach,
  });

  final JigVerbs verbs;
  final String protocolVersion;

  /// Connects to a URI supplied at runtime, or null on a server that cannot.
  ///
  /// An MCP client usually cannot set a working directory, so the session file is
  /// often out of reach: without this the only way to point the server at an app is
  /// to restart it with an environment variable.
  final Future<JigVerbs> Function(String uri)? attach;

  /// What the client's model is told before it sees a single tool.
  ///
  /// This is the only place a server can say how its tools relate to each other.
  /// Without it a model reads thirteen equally-weighted descriptions and picks by
  /// name - which is how `screenshot` becomes the way to ask "what is on screen",
  /// when the answer it wants is in `tree` for a fraction of the cost and with
  /// something it can assert on.
  static const String instructions = '''
jig drives a running Flutter app through its accessibility tree. Use it to learn what the app did, not to describe the app.

Cheapest first:
1. `state`, `events`, `nav` - structured and exact: registered values, what happened since a seq, the route history.
2. `tree` - the elements that exist and the selector each answers to. Read a key or label here before acting on anything.
3. `tap`, `type`, `clear`, `adjust`, `swipe`, `scroll`, `wait` - act on an element, addressed by key, accessibility label, widget type or visible text. `adjust` is the one for a slider: it steps the value and returns the new one.
4. `screenshot` - pixels, and the most expensive call. It returns an image that has to be read, it says nothing about what is actionable, and nothing in it can be asserted on. Reach for it only when the question is visual - a layout, an overlap, a glyph, a colour - or when the accessibility tree cannot name what you need to see. Do not use it to locate an element: that is `tree`.

Never guess a selector. An unknown one fails `ELEMENT_NOT_FOUND` with candidates listing what does exist. A ref from `tree` is a handle for the current frame only; re-read it instead of reusing it.

An ok means the app received the action, not that a gesture landed. `tap` fails `ELEMENT_NOT_VISIBLE` when something covers the target, `swipe` fails `GESTURE_NO_EFFECT` when nothing changed, `clear` fails `CLEAR_REFUSED` when the field keeps its text. The error's candidates and hint name the next call to make.

Every reply carries a seq. Pass it to `events` as since to see only what that call caused.

When a tool answers `NOT_CONNECTED` and the app is already running, call `connect` with the ws:// URI that `jig launch` printed. Connecting is per session, so it fixes a stale or missing session file without a restart.
''';

  /// Protocol versions this server has actually been exercised against.
  static const Set<String> supportedVersions = <String>{
    '2024-11-05',
    '2025-03-26',
  };

  /// The selector, spelled the same way the CLI spells it.
  ///
  /// The descriptions are not decoration: a client hands this schema to a model, and
  /// the model has nothing else to go on. Which spelling is the stable one, that
  /// `index` only means something with `type`, and that one of them is mandatory are
  /// all facts a caller would otherwise learn by failing.
  static const Map<String, Object?> _selectorProperties = <String, Object?>{
    'key': <String, Object?>{
      'type': 'string',
      'description': 'Widget key value. The most stable selector - it survives '
          'copy and layout changes, so prefer it when the app has one.',
    },
    'sem': <String, Object?>{
      'type': 'string',
      'description': 'Accessibility label, as a screen reader says it '
          '(case-insensitive, whitespace collapsed).',
    },
    'text': <String, Object?>{
      'type': 'string',
      'description': 'Visible text, for a widget that exposes no label.',
    },
    'type': <String, Object?>{
      'type': 'string',
      'description': 'Widget runtime type, e.g. IconButton. Last resort: breaks on '
          'any refactor. Pair it with index when several match.',
    },
    'index': <String, Object?>{
      'type': 'integer',
      'description': 'With type: which match to use, 0-based. Default 0.',
    },
    'exact': <String, Object?>{
      'type': 'boolean',
      'description': 'With sem: exact label match (default true) or substring '
          '(false).',
    },
  };

  /// Exactly one selector spelling is required, which `required` cannot express -
  /// so the constraint travels as `anyOf`, the form that is actually true.
  static const Map<String, Object?> _oneSelector = <String, Object?>{
    'anyOf': <Map<String, Object?>>[
      <String, Object?>{'required': <String>['key']},
      <String, Object?>{'required': <String>['sem']},
      <String, Object?>{'required': <String>['text']},
      <String, Object?>{'required': <String>['type']},
    ],
  };

  /// The same constraint for a verb that also accepts a handle (`tap`), so the
  /// schema still says something has to be named.
  static const Map<String, Object?> _oneSelectorOrRef = <String, Object?>{
    'anyOf': <Map<String, Object?>>[
      <String, Object?>{'required': <String>['key']},
      <String, Object?>{'required': <String>['sem']},
      <String, Object?>{'required': <String>['text']},
      <String, Object?>{'required': <String>['type']},
      <String, Object?>{'required': <String>['ref']},
    ],
  };

  static const Map<String, Object?> _selectorSchema = <String, Object?>{
    'type': 'object',
    'description': 'Provide exactly one of key, sem, text or type.',
    'properties': _selectorProperties,
    ..._oneSelector,
  };

  /// A tool schema that carries the selector plus whatever the verb adds.
  ///
  /// [alsoRequired] is for the arguments that are mandatory on their own, so the
  /// schema states them instead of letting the handler reject the call afterwards.
  static Map<String, Object?> _withSelector(
    Map<String, Object?> extra, {
    bool selectorOptional = false,
    List<String> alsoRequired = const <String>[],
  }) => <String, Object?>{
    'type': 'object',
    'description': selectorOptional
        ? 'Provide exactly one of key, sem, text, type or ref.'
        : 'Provide exactly one of key, sem, text or type.',
    'properties': <String, Object?>{..._selectorProperties, ...extra},
    if (alsoRequired.isNotEmpty) 'required': alsoRequired,
    ...selectorOptional ? _oneSelectorOrRef : _oneSelector,
  };

  /// The tool surface a client sees.
  ///
  /// Each description has to stand alone: a model gets no README, only this. So each
  /// one says what the verb does, what it needs, what comes back, and the failure a
  /// caller should expect instead of guessing - the same three things the CLI puts in
  /// an error envelope.
  late final List<JigTool> tools = <JigTool>[
    JigTool(
      name: 'connect',
      description: 'Point the server at a running app, given the VM service URI '
          '`jig launch` prints. Use it when other tools answer NOT_CONNECTED and '
          'the app is already running: connecting is per session, and this replaces '
          'whatever the server started with.',
      schema: <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'uri': <String, Object?>{
            'type': 'string',
            'description': 'The ws:// URI of the app VM service, e.g. '
                'ws://127.0.0.1:41234/abc=/ws. Read it from `jig launch` output.',
          },
        },
        'required': <String>['uri'],
      },
      standalone: (Map<String, Object?> args) async {
        final uri = args['uri'];
        if (uri is! String || uri.isEmpty) {
          throw const JigArgumentException('connect needs a non-empty "uri"');
        }
        final connect = attach;
        if (connect == null) {
          return JigResponse.failure(
            const JigError(
              JigErrorCode.internal,
              'This server cannot connect at runtime',
              hint: 'Restart it with --uri or JIG_URI.',
            ),
          );
        }
        final JigVerbs verbs;
        try {
          verbs = await connect(uri);
        } on JigConnectionException catch (error) {
          return JigResponse.failure(
            JigError(
              JigErrorCode.notConnected,
              error.message,
              hint: 'Check the URI against the `jig launch` output.',
            ),
          );
        }
        final ping = await verbs.ping();
        if (ping.error != null) {
          return ping;
        }
        return JigResponse.ok(<String, Object?>{
          'connected': true,
          'uri': uri,
          'state': ping.data?['state'],
          'route': ping.data?['route'],
        });
      },
    ),
    JigTool(
      name: 'ping',
      description: 'Connection check. Returns the protocol version, the event '
          'sequence, and the names of the state readers the app registered. Start '
          'here when a call fails unexpectedly.',
      handler: (JigVerbs verbs, Map<String, Object?> args) => verbs.ping(),
    ),
    JigTool(
      name: 'tree',
      description: 'List the elements the app exposes to accessibility, with the '
          'selector each one answers to. This is the discovery step: read a key or '
          'label here before calling tap or type. Refuses to guess - an empty list '
          'comes with a reason, and rects are informational only, never inputs.',
      schema: <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'all': <String, Object?>{
            'type': 'boolean',
            'description': 'Include nodes that expose no action, which the default '
                'listing hides. Useful for auditing what is unaddressable.',
          },
          'limit': <String, Object?>{
            'type': 'integer',
            'description': 'Maximum elements to return after filtering. Default 120.',
          },
          'q': <String, Object?>{
            'type': 'string',
            'description': 'Only elements whose key, label or value contains this text, '
                'case-insensitive. A cheap narrowing when the listing is long.',
          },
        },
      },
      handler: (JigVerbs verbs, Map<String, Object?> args) => verbs.tree(
        interactiveOnly: args['all'] != true,
        limit: _int(args['limit']) ?? 120,
        query: args['q'] as String?,
      ),
    ),
    JigTool(
      name: 'tap',
      description: 'Activate an element through its accessibility node. Fails '
          'ELEMENT_NOT_VISIBLE when something covers it - an overlay absorbs the '
          'action, so success here means the app received it, not that a gesture '
          'landed somewhere. Screenshots hold no information about what is '
          'actionable; read tree instead.',
      schema: _withSelector(
        <String, Object?>{
          'ref': <String, Object?>{
            'type': 'string',
            'description': 'A handle from a previous tree listing, e.g. n42, as an '
                'alternative to a selector. It expires the moment the tree rebuilds.',
          },
          'long': <String, Object?>{
            'type': 'boolean',
            'description': 'Long-press instead of tap.',
          },
        },
        selectorOptional: true,
      ),
      handler: (JigVerbs verbs, Map<String, Object?> args) {
        final ref = args['ref'];
        if (ref is String && ref.isNotEmpty) {
          return verbs.tapRef(ref);
        }
        return verbs.tap(selectorOf(args), long: args['long'] == true);
      },
    ),
    JigTool(
      name: 'swipe',
      description: 'Drag an element in a named direction, for the gestures that have '
          'no accessibility action: pull to refresh, reveal swipe actions, dismiss a '
          'sheet. Direction is a name, never a distance or a coordinate. Fails '
          'GESTURE_NO_EFFECT when nothing in the app changed, so a swipe that missed '
          'cannot pass. Name the target with a selector or with a ref from tree - the '
          'ref is what makes a scrollable that has no key of its own reachable.',
      schema: _withSelector(
        <String, Object?>{
          'ref': <String, Object?>{
            'type': 'string',
            'description': 'A handle from a previous tree listing, when the thing to '
                'drag exposes no key, label or type - a bare scrollable, for instance.',
          },
          'direction': <String, Object?>{
            'type': 'string',
            'enum': <String>['left', 'right', 'up', 'down'],
            'description': 'Which way the content moves. Default left.',
          },
        },
        selectorOptional: true,
      ),
      handler: (JigVerbs verbs, Map<String, Object?> args) {
        final ref = args['ref'];
        final hasRef = ref is String && ref.isNotEmpty;
        return verbs.swipe(
          hasRef ? JigSelector.key(ref) : selectorOf(args),
          direction: (args['direction'] as String?) ?? 'left',
          ref: hasRef ? ref : null,
        );
      },
    ),
    JigTool(
      name: 'type',
      description: 'Put text into a field, focusing it first. Fails '
          'ELEMENT_NOT_EDITABLE when nothing editable matches. To empty a field use '
          'clear: this verb refuses an empty value, because reporting what it sent is '
          'not evidence of what the field holds.',
      schema: _withSelector(
        <String, Object?>{
          'value': <String, Object?>{
            'type': 'string',
            'description': 'The text to put in the field. Must be non-empty; use '
                'clear to empty it.',
          },
        },
        alsoRequired: const <String>['value'],
      ),
      handler: (JigVerbs verbs, Map<String, Object?> args) {
        final value = args['value'] as String?;
        if (value == null || value.isEmpty) {
          throw const JigArgumentException(
            'type needs a non-empty "value"; use the clear tool to empty a field',
          );
        }
        return verbs.typeText(selectorOf(args), value);
      },
    ),
    JigTool(
      name: 'clear',
      description: 'Empty a text field and read it back. Fails CLEAR_REFUSED when '
          'text is still there - a formatter, an input mask or a controller that puts '
          'it back - naming what survived. That read-back is the point: an ok means '
          'the field is empty, not that a clear was dispatched.',
      schema: _selectorSchema,
      handler: (JigVerbs verbs, Map<String, Object?> args) =>
          verbs.clear(selectorOf(args)),
    ),
    JigTool(
      name: 'adjust',
      description: 'Move a range control - a slider, a dial - by whole steps and '
          'return the new value. Not for buttons: a stepper built from +/- buttons is '
          'two taps. The step size is the control\'s own, set by its divisions. Fails '
          'ADJUST_REFUSED when the control exposes no steps, is already at its end, or '
          'did not move - so an ok here means the value really changed.',
      schema: _withSelector(<String, Object?>{
        'direction': <String, Object?>{
          'type': 'string',
          'enum': <String>['up', 'down'],
          'description': 'Which way the value moves. Default up.',
        },
        'times': <String, Object?>{
          'type': 'integer',
          'description': 'How many steps to apply. Default 1; must be at least 1.',
        },
      }),
      handler: (JigVerbs verbs, Map<String, Object?> args) => verbs.adjust(
        selectorOf(args),
        direction: (args['direction'] as String?) ?? 'up',
        times: _int(args['times']) ?? 1,
      ),
    ),
    JigTool(
      name: 'screenshot',
      description: 'Capture the rendered frame and return it as a PNG image block, '
          'plus a text block with width, height and byte count. The most expensive '
          'tool, and the only one whose answer has to be read rather than compared: '
          'reach for it when the question is visual, not to find an element - that is '
          'tree - nor to check state, which is state. Platform surfaces - soft '
          'keyboard, native dialogs, webviews - are not in the image.',
      schema: <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'pixelRatio': <String, Object?>{
            'type': 'number',
            'description': 'Scale of the output. Default 1, which is already the '
                'device resolution; 2 re-renders larger.',
          },
        },
      },
      image: true,
      handler: (JigVerbs verbs, Map<String, Object?> args) => verbs.screenshot(
        pixelRatio: _double(args['pixelRatio']) ?? 1,
      ),
    ),
    JigTool(
      name: 'wait',
      description: 'Block until an element is actionable, or until it is gone. '
          'Actionable is stricter than present: waiting for a covered element returns '
          'only when it can actually be acted on, so a wait that passes makes the next '
          'tap safe. Fails TIMEOUT naming what it saw.',
      schema: _withSelector(<String, Object?>{
        'present': <String, Object?>{
          'type': 'boolean',
          'description': 'True (default) waits for the element to become actionable; '
              'false waits for it to disappear.',
        },
        'timeoutMs': <String, Object?>{
          'type': 'integer',
          'description': 'How long to wait before failing. Default 10000.',
        },
      }),
      handler: (JigVerbs verbs, Map<String, Object?> args) => verbs.wait(
        selectorOf(args),
        present: args['present'] != false,
        timeout: Duration(milliseconds: _int(args['timeoutMs']) ?? 10000),
      ),
    ),
    JigTool(
      name: 'scroll',
      description: 'Page a scrollable until an element is reachable, and return its '
          'ref. Use it instead of tapping something off screen: every list is lazily '
          'built, so the target is often not rendered at all. Fails '
          'SCROLL_EXHAUSTED when the budget runs out or the content ends, listing what '
          'was rendered.',
      schema: _withSelector(<String, Object?>{
        'axis': <String, Object?>{
          'type': 'string',
          'enum': <String>['vertical', 'horizontal'],
          'description': 'Which axis to page. Default vertical; a horizontal PageView '
              'needs it named.',
        },
        'steps': <String, Object?>{
          'type': 'integer',
          'description': 'Budget of pages before giving up. Default 20. It is a '
              'budget, not a count: the content ending also stops the scroll.',
        },
        'in': <String, Object?>{
          'type': 'string',
          'description': 'Key, type or label of the scrollable to page, when more '
              'than one could be. Without it, two candidates are ELEMENT_AMBIGUOUS '
              'rather than a guess.',
        },
      }),
      handler: (JigVerbs verbs, Map<String, Object?> args) => verbs.scroll(
        selectorOf(args),
        horizontal: args['axis'] == 'horizontal',
        steps: _int(args['steps']) ?? 20,
        within: args['in'] as String?,
      ),
    ),
    JigTool(
      name: 'state',
      description: 'Read the values the app registered with Jig.state(...). This is '
          'the reliable half of introspection: no source evaluation, one call for the '
          'whole snapshot. An unregistered name comes back as an error per entry '
          'rather than as a missing key, so a typo is visible.',
      schema: <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'names': <String, Object?>{
            'type': 'array',
            'items': <String, Object?>{'type': 'string'},
            'description': 'Which readers to read. Omit for every reader the app '
                'registered, which also tells you their names.',
          },
        },
      },
      handler: (JigVerbs verbs, Map<String, Object?> args) => verbs.state(
        names: (args['names'] as List<Object?>?)?.cast<String>(),
      ),
    ),
    JigTool(
      name: 'events',
      description: 'Read what the app recorded since a sequence number: HTTP '
          'exchanges, log lines, navigation, unhandled errors, custom events. Use the '
          'seq a previous reply reported to see only what that action caused.',
      schema: <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'since': <String, Object?>{
            'type': 'integer',
            'description': 'Sequence number to start after. Default 0, the whole '
                'buffer.',
          },
          'limit': <String, Object?>{
            'type': 'integer',
            'description': 'Maximum events to return. Default 100.',
          },
          'sources': <String, Object?>{
            'type': 'array',
            'items': <String, Object?>{
              'type': 'string',
              'enum': <String>['http', 'log', 'nav', 'error', 'state', 'custom'],
            },
            'description': 'Only these sources. Omit for all of them.',
          },
        },
      },
      handler: (JigVerbs verbs, Map<String, Object?> args) => verbs.events(
        since: _int(args['since']) ?? 0,
        sources: _sources(args['sources']),
        limit: _int(args['limit']) ?? 100,
      ),
    ),
    JigTool(
      name: 'nav',
      description: 'Read the route history: the current route and how the app got '
          'there. Answers "did navigation happen" without inferring it from a '
          'screenshot.',
      handler: (JigVerbs verbs, Map<String, Object?> args) => verbs.nav(),
    ),
    JigTool(
      name: 'back',
      description: 'Leave the route the way the system back button does, so PopScope '
          'and canPop are honoured and stacked modals are dismissed in the framework '
          'order. Fails BACK_REFUSED when nothing popped - being told "no" is the '
          'point, since a blocked pop that reported success would look identical to a '
          'working one.',
      handler: (JigVerbs verbs, Map<String, Object?> args) => verbs.back(),
    ),
  ];

  /// The selector an argument map names, in the same spellings the CLI accepts.
  static JigSelector selectorOf(Map<String, Object?> args) {
    final semantic = args['sem'];
    final key = args['key'];
    final type = args['type'];
    final text = args['text'];
    if (semantic is String && semantic.isNotEmpty) {
      return JigSelector.semantic(
        semantic,
        exact: args['exact'] as bool? ?? true,
      );
    }
    if (key is String && key.isNotEmpty) {
      return JigSelector.key(key);
    }
    if (type is String && type.isNotEmpty) {
      return JigSelector.widgetType(type, index: _int(args['index']) ?? 0);
    }
    if (text is String && text.isNotEmpty) {
      return JigSelector.text(text);
    }
    throw const JigArgumentException(
      'Provide one of: sem, key, type, text',
    );
  }

  /// Answers one message, or returns null when no answer is owed.
  Future<Map<String, Object?>?> handle(Map<String, Object?> message) async {
    final parsed = JigRpcMessage(
      id: message['id'],
      method: message['method'] as String? ?? '',
      params: (message['params'] as Map<String, Object?>?) ??
          const <String, Object?>{},
    );

    switch (parsed.method) {
      case 'initialize':
        final requested = parsed.params['protocolVersion'];
        return JigRpcMessage.result(parsed.id, <String, Object?>{
          // Echo the version only when it is one this server has been exercised
          // against; otherwise advertise our own and let the client decide.
          'protocolVersion': supportedVersions.contains(requested)
              ? requested
              : protocolVersion,
          'capabilities': <String, Object?>{
            'tools': <String, Object?>{},
          },
          'serverInfo': <String, Object?>{
            'name': 'jig',
            'version': '0.1.0-dev.1',
          },
          'instructions': instructions,
        });

      case 'notifications/initialized':
      case 'initialized':
        return null;

      case 'ping':
        return JigRpcMessage.result(parsed.id, const <String, Object?>{});

      case 'tools/list':
        return JigRpcMessage.result(parsed.id, <String, Object?>{
          'tools': <Map<String, Object?>>[
            for (final tool in tools)
              <String, Object?>{
                'name': tool.name,
                'description': tool.description,
                'inputSchema': tool.schema,
              },
          ],
        });

      case 'tools/call':
        return _call(parsed);

      default:
        if (parsed.isNotification) {
          return null;
        }
        return JigRpcMessage.error(
          parsed.id,
          JigRpcCode.methodNotFound,
          'Unknown method ${parsed.method}',
        );
    }
  }

  /// Runs one tool and wraps the result the way MCP expects it.
  ///
  /// An app-side failure is `isError: true` with the jig error JSON inside: the tool
  /// ran, and what it asked for failed. Returning a JSON-RPC error instead would tell
  /// the client the server itself broke.
  Future<Map<String, Object?>?> _call(JigRpcMessage message) async {
    final name = message.params['name'];
    final tool = tools.where((JigTool t) => t.name == name).firstOrNull;
    if (tool == null) {
      return JigRpcMessage.error(
        message.id,
        JigRpcCode.invalidParams,
        '"$name" is not a tool. One of: ${tools.map((JigTool t) => t.name).join(', ')}',
      );
    }
    final rawArgs = message.params['arguments'];
    final args = rawArgs is Map<String, Object?>
        ? rawArgs
        : const <String, Object?>{};

    final standalone = tool.standalone;
    final handler = tool.handler;
    if (standalone == null && handler == null) {
      return JigRpcMessage.error(
        message.id,
        JigRpcCode.internal,
        '"${tool.name}" has no handler',
      );
    }

    final JigResponse response;
    try {
      response = await (standalone != null
          ? standalone(args)
          : handler!(verbs, args));
    } on JigArgumentException catch (error) {
      // Bad arguments are the client's mistake, so they are a protocol error rather
      // than a tool result: the tool did not run at all.
      return JigRpcMessage.error(
        message.id,
        JigRpcCode.invalidParams,
        error.message,
      );
    } on JigScenarioException catch (error) {
      return JigRpcMessage.error(
        message.id,
        JigRpcCode.invalidParams,
        error.toString(),
      );
    } catch (error) {
      // A transport failure is the app's absence, not a broken server - and an
      // exception that escapes here would take the whole stdio loop with it, which
      // is the one failure a client cannot recover from without a restart.
      return JigRpcMessage.result(
        message.id,
        _text(
          <String, Object?>{
            'code': JigErrorCode.internal.wire,
            'message': error.toString(),
          },
          isError: true,
        ),
      );
    }

    final error = response.error;
    if (error != null) {
      return JigRpcMessage.result(message.id, _text(error.toJson(), isError: true));
    }
    if (tool.image) {
      return JigRpcMessage.result(message.id, _image(response.data));
    }
    return JigRpcMessage.result(message.id, _text(response.data, isError: false));
  }

  /// An image result: the bytes a client renders, plus the facts about them.
  ///
  /// The dimensions travel as a separate text block because they are what a caller
  /// asserts on and quotes; the model that wants pixels takes the image block.
  static Map<String, Object?> _image(Map<String, Object?>? data) {
    final encoded = data?['base64'];
    if (data == null || encoded is! String || data['format'] != 'png') {
      return _text(
        <String, Object?>{'error': 'the app returned no image'},
        isError: true,
      );
    }
    return <String, Object?>{
      'content': <Map<String, Object?>>[
        <String, Object?>{
          'type': 'image',
          'data': encoded,
          'mimeType': 'image/png',
        },
        <String, Object?>{
          'type': 'text',
          'text': const JsonEncoder.withIndent('  ').convert(<String, Object?>{
            for (final entry in data.entries)
              if (entry.key != 'base64') entry.key: entry.value,
          }),
        },
      ],
      'isError': false,
    };
  }

  /// MCP tool results are content blocks, so the payload travels as JSON text.
  static Map<String, Object?> _text(Object? payload, {required bool isError}) =>
      <String, Object?>{
        'content': <Map<String, Object?>>[
          <String, Object?>{
            'type': 'text',
            'text': const JsonEncoder.withIndent('  ').convert(payload),
          },
        ],
        'isError': isError,
      };

  static int? _int(Object? raw) => raw is num ? raw.toInt() : null;

  static double? _double(Object? raw) => raw is num ? raw.toDouble() : null;

  static Set<JigSource>? _sources(Object? raw) {
    if (raw is! List<Object?>) {
      return null;
    }
    return <JigSource>{
      for (final name in raw)
        if (name is String)
          JigSource.values.firstWhere(
            (JigSource source) => source.name == name,
            orElse: () => JigSource.custom,
          ),
    };
  }
}
