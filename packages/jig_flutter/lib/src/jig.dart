import 'dart:developer' as developer;

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:jig_protocol/jig_protocol.dart';

import 'bus.dart';
import 'extensions.dart';
import 'nav_history.dart';
import 'state_registry.dart';

/// The logger shape Flutter apps already use for GetX's `logWriterCallback`,
/// declared structurally so this package does not depend on `get`.
typedef JigLogWriter = void Function(String text, {bool isError});

/// Entry point for the app side.
///
/// Intended for debug builds only: it enables the semantics tree, registers VM
/// service extensions and taps the global error handler.
abstract final class Jig {
  static bool _installed = false;
  static SemanticsHandle? _semanticsHandle;
  static JigLogWriter? _forwardLogs;
  static void Function(FlutterErrorDetails)? _previousFlutterErrorHandler;
  static bool _hasPreviousFlutterErrorHandler = false;

  static final NavigatorObserver navigatorObserver = JigNavigatorObserver();

  static bool get isInstalled => _installed;

  /// Installs the runtime. Idempotent.
  ///
  /// [forwardLogs] receives what [logWriter] captures after it has been recorded,
  /// so wiring this up does not silence the app's existing logging.
  static void install({
    bool semantics = true,
    bool captureErrors = true,
    bool mirrorToVmService = true,
    JigLogWriter? forwardLogs,
  }) {
    if (_installed) {
      return;
    }
    _installed = true;

    JigBus.instance.postToVmService = mirrorToVmService;
    _forwardLogs = forwardLogs ?? _logToDeveloper;

    if (semantics) {
      _semanticsHandle ??= SemanticsBinding.instance.ensureSemantics();
    }

    if (captureErrors) {
      _previousFlutterErrorHandler = FlutterError.onError;
      _hasPreviousFlutterErrorHandler = true;
      FlutterError.onError = _handleFlutterError;
    }

    JigExtensions.register();
    JigBus.instance.emit(JigSource.custom, 'installed', <String, Object?>{
      'protocol': jigProtocolVersion,
      'semantics': semantics,
    });
  }

  /// Releases the semantics handle and restores the previous error handler.
  /// Registered extensions stay in place for the life of the isolate.
  static void uninstall() {
    if (!_installed) {
      return;
    }
    if (_hasPreviousFlutterErrorHandler) {
      FlutterError.onError = _previousFlutterErrorHandler;
      _hasPreviousFlutterErrorHandler = false;
    }
    _semanticsHandle?.dispose();
    _semanticsHandle = null;
    _installed = false;
  }

  /// Registers a named value readable through `jig snapshot`.
  static void state(String name, Object? Function() read) =>
      JigStateRegistry.register(name, read);

  /// Structurally compatible with GetX's `LogWriterCallback`, so
  /// `GetMaterialApp(logWriterCallback: Jig.logWriter)` compiles untouched.
  static void logWriter(String text, {bool isError = false}) {
    JigBus.instance.emit(
      JigSource.log,
      isError ? 'error' : 'info',
      <String, Object?>{'text': text},
    );
    _forwardLogs?.call(text, isError: isError);
  }

  static void _logToDeveloper(String text, {bool isError = false}) {
    developer.log(text, name: 'APP');
  }

  static void _handleFlutterError(FlutterErrorDetails details) {
    final stack = details.stack;
    JigBus.instance.emit(JigSource.error, 'flutter', <String, Object?>{
      'message': details.exceptionAsString(),
      if (details.library != null) 'library': details.library,
      if (stack != null)
        'stack': stack.toString().split('\n').take(12).join('\n'),
    });
    // Never swallow the app's own handling: Crashlytics and friends still need
    // to see the failure.
    _previousFlutterErrorHandler?.call(details);
  }
}
