import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jig_flutter/jig_flutter.dart';
import 'package:jig_protocol/jig_protocol.dart';

/// Mounts [page] the way `main.dart` mounts a route, minus the parts a test must
/// not start: no backend, no controllers unless the page needs them.
///
/// Semantics is turned on explicitly. Every verb reads the accessibility tree, and
/// without a handle the tree is empty, so a selector would miss for a reason
/// that has nothing to do with what is being tested.
Future<SemanticsHandle> pumpPage(WidgetTester tester, Widget page) async {
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(
    GetMaterialApp(
      home: page,
      navigatorObservers: <NavigatorObserver>[Jig.navigatorObserver],
    ),
  );
  await tester.pump();
  return handle;
}

/// Runs [body] with [page] mounted, disposing the semantics handle afterwards.
///
/// The handle has to be released inside the test body: `flutter_test` verifies
/// that no handle outlives the test, and `addTearDown` runs too late for that.
Future<void> withPage(
  WidgetTester tester,
  Widget page,
  Future<void> Function() body,
) async {
  final handle = await pumpPage(tester, page);
  try {
    await body();
  } finally {
    await drainSnackbars(tester);
    handle.dispose();
  }
}

/// Lets a GetX snackbar finish before the tree goes away.
///
/// It holds an entrance animation, a 3s auto-dismiss timer and an exit animation,
/// and `flutter_test` fails the test when any of them outlives it. Draining here
/// keeps every test from having to know that a tap happened to raise a snackbar.
Future<void> drainSnackbars(
  WidgetTester tester, {
  Duration wait = const Duration(seconds: 5),
}) async {
  await tester.pump();
  await tester.pump(wait);
  await tester.pumpAndSettle();
}

/// Drives frames until [isDone] reports true.
///
/// Frames are driven from the test on purpose: under `testWidgets` a frame only
/// happens when one is pumped, so anything that waits on `endOfFrame` on its own
/// never completes.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() isDone, {
  int maxFrames = 400,
}) async {
  for (var frame = 0; frame < maxFrames; frame++) {
    if (isDone()) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 16));
  }
  if (!isDone()) {
    fail('The condition never became true within $maxFrames frames.');
  }
}

/// Awaits [action] while pumping frames so the in-app wait can finish.
///
/// `JigActions._settle` awaits `SchedulerBinding.endOfFrame`, so awaiting a verb
/// future directly deadlocks the test. Pumping from here keeps production code
/// free of test-only timing; nothing is slept on.
Future<T> drive<T>(
  WidgetTester tester,
  Future<T> action, {
  int maxFrames = 400,
}) async {
  var done = false;
  Object? failure;
  late T result;
  unawaited(
    action.then(
      (T value) {
        result = value;
        done = true;
      },
      onError: (Object error) {
        failure = error;
        done = true;
      },
    ),
  );
  await pumpUntil(tester, () => done, maxFrames: maxFrames);
  final error = failure;
  if (error != null) {
    throw error;
  }
  return result;
}

/// Awaits [action] while pumping frames, returning its failure instead of
/// throwing so an expected error can be asserted.
Future<JigError?> driveFailure(
  WidgetTester tester,
  Future<Map<String, Object?>> action, {
  int maxFrames = 400,
}) async {
  try {
    await drive(tester, action, maxFrames: maxFrames);
    return null;
  } on JigActionFailure catch (failure) {
    return failure.error;
  }
}

/// Awaits [action] while pumping frames *and* letting the engine's own event loop
/// run.
///
/// Pumping advances the fake clock, which is enough for a verb that settles on a
/// frame. A capture finishes on the raster thread, and that callback is only
/// delivered through real async, so the two have to be interleaved - the same
/// reason golden files run their comparison through `runAsync`.
Future<T> driveAsync<T>(
  WidgetTester tester,
  Future<T> action, {
  int maxRounds = 400,
}) async {
  var done = false;
  Object? failure;
  late T result;
  unawaited(
    action.then(
      (T value) {
        result = value;
        done = true;
      },
      onError: (Object error) {
        failure = error;
        done = true;
      },
    ),
  );
  for (var round = 0; round < maxRounds && !done; round++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  if (!done) {
    fail('The action never completed within $maxRounds rounds.');
  }
  final error = failure;
  if (error != null) {
    throw error;
  }
  return result;
}

/// The error a verb threw, or `null` when it returned normally.
///
/// A verb that answers `ok` for something that did not happen is the defect class
/// this suite exists for, so most tests start by looking here.
JigError? errorOf(Object? thrown) =>
    thrown is JigActionFailure ? thrown.error : null;

/// Runs [action] and hands its outcome to the test as a value, so an expected
/// failure is asserted rather than swallowed.
@pragma('vm:prefer-inline')
Object? attempt(Map<String, Object?> Function() action) {
  try {
    action();
    return null;
  } on JigActionFailure catch (failure) {
    return failure;
  }
}
