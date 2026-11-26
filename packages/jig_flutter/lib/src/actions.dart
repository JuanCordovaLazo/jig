import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:jig_protocol/jig_protocol.dart';

import 'bus.dart';
import 'element_index.dart';
import 'nav_history.dart';
import 'state_registry.dart';

/// Thrown when an action cannot be performed; carries the wire error so the
/// extension layer reports it instead of a stack trace.
final class JigActionFailure implements Exception {
  const JigActionFailure(this.error);

  final JigError error;

  @override
  String toString() => error.toString();
}

/// The four directions a swipe can take.
///
/// Named rather than numeric on purpose: a caller who supplies a delta is doing
/// the arithmetic that expires silently, which is what this project removed.
enum JigSwipeDirection {
  left,
  right,
  up,
  down;

  bool get isHorizontal => this == left || this == right;

  /// Unit vector pointing the way the content moves.
  Offset get delta => switch (this) {
    JigSwipeDirection.left => const Offset(-1, 0),
    JigSwipeDirection.right => const Offset(1, 0),
    JigSwipeDirection.up => const Offset(0, -1),
    JigSwipeDirection.down => const Offset(0, 1),
  };

  static JigSwipeDirection? parse(String? raw) {
    for (final direction in values) {
      if (direction.name == raw) {
        return direction;
      }
    }
    return null;
  }
}

/// Acts on the app the way the accessibility layer would.
///
/// Two rules make this different from pointer injection:
///
/// * the caller never supplies a coordinate - a position is computed from the
///   widget's own render box at the instant of the action, so a rebuild between
///   "find" and "tap" cannot make it stale;
/// * the action goes through [SemanticsOwner], so an overlay either receives it
///   or the operation fails loudly. There is no fallback that calls a callback
///   directly.
abstract final class JigActions {
  static const List<SemanticsAction> _kScrollActions = <SemanticsAction>[
    SemanticsAction.scrollUp,
    SemanticsAction.scrollDown,
    SemanticsAction.scrollLeft,
    SemanticsAction.scrollRight,
  ];

  static Map<String, Object?> tap(JigSelector selector, {bool long = false}) {
    final action = long ? SemanticsAction.longPress : SemanticsAction.tap;

    final match = JigElementIndex.findByLabel(
      selector.value,
      exact: selector.exact,
    ).nodeOrNull(selector);
    if (match != null) {
      match.owner.performAction(match.node.id, action);
      _record('tap', selector, ref: 'n${match.node.id}');
      return <String, Object?>{
        'ref': 'n${match.node.id}',
        'label': match.node.getSemanticsData().label,
        'action': action.name,
      };
    }

    final element = _findElement(selector);
    if (element == null) {
      throw JigActionFailure(_notFound(selector));
    }

    // A node id cannot go stale and carries the action the framework will
    // actually run. There is deliberately no coordinate fallback: when the
    // element exists but exposes no such action it is either covered by a modal
    // or missing semantics, and reporting success for a gesture that never
    // reached it is the failure this project exists to remove.
    final target = _liveActionableNode(element, action);
    if (target == null) {
      throw JigActionFailure(
        JigError(
          JigErrorCode.elementNotVisible,
          '${selector.describe()} resolves to a widget, but no semantics node '
          'exposes ${action.name}',
          candidates: JigElementIndex.labels(),
          hint: 'It is probably behind a modal. Read jig tree to see what is '
              'reachable now.',
        ),
      );
    }
    target.owner.performAction(target.node.id, action);
    _record('tap', selector, ref: 'n${target.node.id}');
    return <String, Object?>{
      'ref': 'n${target.node.id}',
      'label': target.node.getSemanticsData().label,
      'action': action.name,
    };
  }

  /// Nearest ancestor that advertises [action] *and* is still in the semantics
  /// tree.
  ///
  /// [RenderObject.debugSemantics] keeps the last node it computed, so a widget
  /// that an overlay has since hidden still reports an actionable node whose id
  /// no longer resolves. Believing it is how a covered tap reports success, so
  /// liveness is checked against the current tree.
  static ({SemanticsOwner owner, SemanticsNode node})? _liveActionableNode(
    Element element,
    SemanticsAction action,
  ) {
    final node = _nearestActionableNode(element, action);
    if (node == null) {
      return null;
    }
    final owner = JigElementIndex.ownerOf(node.id);
    if (owner == null) {
      return null;
    }
    return (owner: owner, node: node);
  }

  /// Nearest ancestor whose semantics node advertises [action].
  ///
  /// [RenderObject.debugSemantics] is debug-only, which matches this runtime:
  /// jig is never installed in a release build.
  static SemanticsNode? _nearestActionableNode(
    Element element,
    SemanticsAction action,
  ) {
    var renderObject = element.renderObject;
    while (renderObject != null) {
      final node = renderObject.debugSemantics;
      if (node != null && node.getSemanticsData().hasAction(action)) {
        return node;
      }
      renderObject = renderObject.parent;
    }
    return null;
  }

  static Future<Map<String, Object?>> typeText(
    JigSelector selector,
    String text,
  ) async {
    final labelled = JigElementIndex.findByLabel(
      selector.value,
      exact: selector.exact,
    );
    var match = labelled.matches == 0 ? null : labelled.nodeOrNull(selector);

    if (match != null &&
        !match.node.getSemanticsData().hasAction(SemanticsAction.setText) &&
        match.node.getSemanticsData().hasAction(SemanticsAction.focus)) {
      // Flutter only advertises `setText` while the field has focus, so focusing
      // is part of typing rather than a step the caller has to remember.
      match.owner.performAction(match.node.id, SemanticsAction.focus);
      match = await _awaitSetText(selector, match.node.id) ?? match;
    }

    if (match != null &&
        match.node.getSemanticsData().hasAction(SemanticsAction.setText)) {
      match.owner.performAction(match.node.id, SemanticsAction.setText, text);
      _record(
        'type',
        selector,
        ref: 'n${match.node.id}',
        extra: <String, Object?>{'text': text},
      );
      return <String, Object?>{
        'ref': 'n${match.node.id}',
        'via': 'semantics',
        'text': text,
      };
    }

    final state = _findEditableText(selector);
    if (state == null) {
      throw JigActionFailure(
        JigError(
          JigErrorCode.elementNotEditable,
          'No editable field matches ${selector.describe()}',
          candidates: JigElementIndex.labels(),
          hint: "jig find --sem '<label>' y luego "
              "jig type --sem '<label>' --value '...'",
        ),
      );
    }
    state.widget.focusNode.requestFocus();
    state.updateEditingValue(
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
    );
    _record('type', selector, extra: <String, Object?>{'text': text});
    return <String, Object?>{'via': 'editableText', 'text': text};
  }

  /// Empties an editable field, then reads it back.
  ///
  /// `type` sends text and reports what it sent, which is not the same as proof.
  /// A formatter, an input mask, or a controller that refuses the change leaves
  /// text in the field, so the answer to "is it empty?" has to be read after the
  /// frame that applied it. Anything still there is [JigErrorCode.clearRefused]
  /// naming what survived.
  static Future<Map<String, Object?>> clearText(JigSelector selector) async {
    final labelled = JigElementIndex.findByLabel(
      selector.value,
      exact: selector.exact,
    );
    var match = labelled.matches == 0 ? null : labelled.nodeOrNull(selector);

    if (match != null &&
        !match.node.getSemanticsData().hasAction(SemanticsAction.setText) &&
        match.node.getSemanticsData().hasAction(SemanticsAction.focus)) {
      match.owner.performAction(match.node.id, SemanticsAction.focus);
      match = await _awaitSetText(selector, match.node.id) ?? match;
    }

    if (match != null &&
        match.node.getSemanticsData().hasAction(SemanticsAction.setText)) {
      match.owner.performAction(match.node.id, SemanticsAction.setText, '');
      await _settle();
      // Node ids are rebuilt per frame, so the node that answers this is not
      // necessarily the one that received the action.
      final after = _liveField(selector);
      if (after == null) {
        throw JigActionFailure(
          JigError(
            JigErrorCode.clearRefused,
            'The field that matched ${selector.describe()} is no longer in the '
            'tree, so the clear cannot be confirmed',
            candidates: JigElementIndex.labels(),
            hint: 'jig find ${selector.describe()}',
          ),
        );
      }
      final left = after.node.getSemanticsData().value;
      if (left.isNotEmpty) {
        throw _clearRefused(selector, left);
      }
      _record('clear', selector, ref: 'n${after.node.id}');
      return <String, Object?>{
        'ref': 'n${after.node.id}',
        'via': 'semantics',
        'text': '',
      };
    }

    final state = _findEditableText(selector);
    if (state == null) {
      throw JigActionFailure(
        JigError(
          JigErrorCode.elementNotEditable,
          'No editable field matches ${selector.describe()}',
          candidates: JigElementIndex.labels(),
          hint: "jig find --sem '<label>'",
        ),
      );
    }
    state.updateEditingValue(TextEditingValue.empty);
    await _settle();
    final left = state.textEditingValue.text;
    if (left.isNotEmpty) {
      throw _clearRefused(selector, left);
    }
    _record('clear', selector);
    return <String, Object?>{'via': 'editableText', 'text': ''};
  }

  /// The field that answers to [selector] right now, if it is still there.
  static ({SemanticsOwner owner, SemanticsNode node})? _liveField(
    JigSelector selector,
  ) {
    final labelled = JigElementIndex.findByLabel(
      selector.value,
      exact: selector.exact,
    );
    return labelled.matches == 0 ? null : labelled.nodeOrNull(selector);
  }

  static JigActionFailure _clearRefused(JigSelector selector, String left) {
    return JigActionFailure(
      JigError(
        JigErrorCode.clearRefused,
        'The field still holds "$left" after clearing ${selector.describe()}',
        candidates: <String>[left],
        hint: 'The app put it back: read it with jig find, or act on whatever '
            'reformats it.',
      ),
    );
  }

  /// Moves a range control by whole steps, and reads the value back.
  ///
  /// A slider has no tap action: it advertises `increase` and `decrease`, which the
  /// framework applies one step at a time - `divisions` decide the step. That is a
  /// different verb from `tap`, not a different way to spell it: the caller wants a
  /// value, and what comes back is the value.
  ///
  /// The proof is the value itself. The node reports what it holds, and the framework
  /// reports what the next step would make it, so a control already at its end is
  /// refused before anything is dispatched. A step that leaves the value where it was
  /// is a refusal too - reporting `ok` there is the defect this project exists for.
  static Future<Map<String, Object?>> adjust(
    JigSelector selector, {
    required bool increase,
    int times = 1,
  }) async {
    if (times < 1) {
      throw const JigActionFailure(
        JigError(
          JigErrorCode.invalidArgument,
          'times must be at least 1',
          hint: 'jig adjust --key <key> --times 1',
        ),
      );
    }
    final action = increase
        ? SemanticsAction.increase
        : SemanticsAction.decrease;
    final direction = increase ? 'up' : 'down';

    String? before;
    var applied = 0;

    for (var step = 0; step < times; step++) {
      // Re-resolved every time: the tree is rebuilt after each step, so the node
      // that answers the next action is not the one that answered the last.
      final target = _liveAdjustable(selector, action);
      if (target == null) {
        throw JigActionFailure(
          JigError(
            JigErrorCode.adjustRefused,
            '${selector.describe()} exposes no ${action.name} action',
            candidates: JigElementIndex.labels(),
            hint: 'This verb is for range controls - a slider, a dial, anything that '
                'advertises increase/decrease. A stepper made of buttons is a '
                'jig tap on the button itself.',
          ),
        );
      }
      final data = target.node.getSemanticsData();
      before ??= data.value;
      final next = increase ? data.increasedValue : data.decreasedValue;
      if (next.isNotEmpty && next == data.value) {
        throw JigActionFailure(
          JigError(
            JigErrorCode.adjustRefused,
            '${selector.describe()} is already at its '
            '${increase ? 'maximum' : 'minimum'}'
            '${data.value.isEmpty ? '' : ' (${data.value})'}',
            candidates: <String>[if (data.value.isNotEmpty) data.value],
            hint: 'Reverse the direction, or read what it holds with jig find.',
          ),
        );
      }
      target.owner.performAction(target.node.id, action);
      await _settle();
      applied++;
    }

    final after = _liveAdjustable(selector, action);
    if (after == null) {
      throw JigActionFailure(
        JigError(
          JigErrorCode.adjustRefused,
          '${selector.describe()} stopped being adjustable after '
          '$applied step${applied == 1 ? '' : 's'}; it may have been disabled',
          candidates: JigElementIndex.labels(),
          hint: 'Read jig tree to see what is reachable now.',
        ),
      );
    }
    final value = after.node.getSemanticsData().value;
    if (value.isEmpty) {
      throw JigActionFailure(
        JigError(
          JigErrorCode.adjustRefused,
          '${selector.describe()} reports no value, so the change cannot be '
          'confirmed',
          hint: 'Read it with jig find, or act on the control it drives instead.',
        ),
      );
    }
    if (before != null && before.isNotEmpty && value == before) {
      throw JigActionFailure(
        JigError(
          JigErrorCode.adjustRefused,
          '${selector.describe()} stayed at $value after '
          '$applied step${applied == 1 ? '' : 's'} $direction',
          candidates: <String>[value],
          hint: 'The control may be mid-animation or clamped; read jig tree.',
        ),
      );
    }

    _record(
      'adjust',
      selector,
      ref: 'n${after.node.id}',
      extra: <String, Object?>{'direction': direction, 'times': applied},
    );
    return <String, Object?>{
      'ref': 'n${after.node.id}',
      'action': action.name,
      'direction': direction,
      'steps': applied,
      if (before != null && before.isNotEmpty) 'previousValue': before,
      'value': value,
    };
  }

  /// The range control that answers to [selector] and advertises [action].
  ///
  /// Labels are searched first, because a control is usually addressed by what it
  /// says. Keys and types need the widget tree, and that is where the asymmetry with
  /// `tap` lives: `Slider` carries the caller's key while the node advertising
  /// `increase`/`decrease` belongs to a *descendant* render object, so the search has
  /// to go down as well as up. `tap` deliberately does not - looking down there would
  /// let a key on a row resolve to a button inside it - and the difference is a
  /// property of the semantics tree, not a preference.
  static ({SemanticsOwner owner, SemanticsNode node})? _liveAdjustable(
    JigSelector selector,
    SemanticsAction action,
  ) {
    final labelled = JigElementIndex.findByLabel(
      selector.value,
      exact: selector.exact,
    );
    final byLabel = labelled.matches == 0 ? null : labelled.nodeOrNull(selector);
    if (byLabel != null && byLabel.node.getSemanticsData().hasAction(action)) {
      return byLabel;
    }
    final element = _findElement(selector);
    if (element == null) {
      return null;
    }
    return _liveActionableNode(element, action) ??
        _liveNodeBelow(element, action);
  }

  /// The first node inside [element]'s subtree that advertises [action].
  ///
  /// Pre-order, so the shallowest match wins - which for a control is the control
  /// itself rather than something nested in it. Depth-bounded because Flutter nests
  /// a slider six widget layers deep before the render object that owns the node, and
  /// an unbounded walk over a long list would be a stall.
  static ({SemanticsOwner owner, SemanticsNode node})? _liveNodeBelow(
    Element element,
    SemanticsAction action,
  ) {
    ({SemanticsOwner owner, SemanticsNode node})? found;

    void visit(Element candidate, int depth) {
      if (found != null || depth > 24) {
        return;
      }
      final node = candidate.renderObject?.debugSemantics;
      if (node != null && node.getSemanticsData().hasAction(action)) {
        final owner = JigElementIndex.ownerOf(node.id);
        if (owner != null) {
          found = (owner: owner, node: node);
          return;
        }
      }
      candidate.visitChildren((Element child) => visit(child, depth + 1));
    }

    visit(element, 0);
    return found;
  }

  /// Captures the frame the engine composited, as PNG.
  ///
  /// The root layer is used because asking an app to wrap itself in a
  /// `RepaintBoundary` would make the harness a change to the app. This is the
  /// same route `flutter_driver` takes. Platform views are not in the image: what
  /// is reported is the Flutter frame, which is the surface the accessibility tree
  /// also describes.
  static Future<Map<String, Object?>> screenshot({
    double pixelRatio = 1,
  }) async {
    if (!pixelRatio.isFinite || pixelRatio <= 0) {
      throw const JigActionFailure(
        JigError(
          JigErrorCode.invalidArgument,
          'pixelRatio must be a positive number',
          hint: 'jig screenshot --pixel-ratio 1',
        ),
      );
    }
    final view = RendererBinding.instance.renderViews.firstOrNull;
    final layer = view?.debugLayer;
    if (view == null || layer is! OffsetLayer) {
      throw const JigActionFailure(
        JigError(
          JigErrorCode.internal,
          'The root layer is not painted, so there is nothing to capture',
          hint: 'Wait for a frame, then retry: jig wait --key <something>',
        ),
      );
    }

    // A capture taken mid-animation is a picture of a frame nobody saw finish.
    await _settle();
    final image = await layer.toImage(
      view.paintBounds,
      pixelRatio: pixelRatio,
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw const JigActionFailure(
          JigError(JigErrorCode.internal, 'The captured frame could not be '
              'encoded as PNG'),
        );
      }
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      return <String, Object?>{
        'format': 'png',
        'width': image.width,
        'height': image.height,
        'bytes': bytes.length,
        'pixelRatio': pixelRatio,
        'base64': base64Encode(bytes),
      };
    } finally {
      image.dispose();
    }
  }

  /// Waits for the focused node to start advertising `setText`.
  ///
  /// Semantics are recomputed per frame, so the action appears on the next one.
  /// The node id is re-resolved first because a rebuild can replace the node.
  static Future<({SemanticsOwner owner, SemanticsNode node})?> _awaitSetText(
    JigSelector selector,
    int id, {
    Duration timeout = const Duration(milliseconds: 1000),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      final same = JigElementIndex.resolveRef('n$id');
      if (same != null &&
          same.node.getSemanticsData().hasAction(SemanticsAction.setText)) {
        return same;
      }
      final relabelled = JigElementIndex.findByLabel(
        selector.value,
        exact: selector.exact,
      );
      final node = relabelled.node;
      final owner = relabelled.owner;
      if (relabelled.matches == 1 &&
          node != null &&
          owner != null &&
          node.getSemanticsData().hasAction(SemanticsAction.setText)) {
        return (owner: owner, node: node);
      }
    }
    return null;
  }

  /// Taps an element the caller obtained from a previous listing.
  static Map<String, Object?> tapRef(String ref) {
    final resolved = JigElementIndex.resolveRef(ref);
    if (resolved == null) {
      throw JigActionFailure(
        JigError(
          JigErrorCode.elementNotFound,
          'No node with ref $ref in the current frame',
          candidates: JigElementIndex.labels(),
          hint: 'Refs expire between frames; re-read them with jig tree.',
        ),
      );
    }
    final data = resolved.node.getSemanticsData();
    if (!data.hasAction(SemanticsAction.tap) &&
        !data.hasAction(SemanticsAction.longPress)) {
      throw JigActionFailure(
        JigError(
          JigErrorCode.elementNotFound,
          '$ref exposes no tap action (label: ${data.label})',
          candidates: JigElementIndex.labels(),
          hint: 'List actionable nodes with jig tree',
        ),
      );
    }
    resolved.owner.performAction(resolved.node.id, SemanticsAction.tap);
    return <String, Object?>{'ref': ref, 'label': data.label};
  }

  /// Drags an element in a named direction.
  ///
  /// This is the only verb that emits pointer events, because a swipe has no
  /// semantics action to perform: `Slidable`'s buttons do not exist until the drag
  /// happens, and `RefreshIndicator` publishes nothing at all. It is still not a
  /// coordinate selector - the caller names a direction and an element, and the
  /// path is computed from that element's own box at the instant of the action.
  ///
  /// Two proofs, and both must hold:
  ///
  /// * the origin hit-tests to the target, so a covered element fails before
  ///   anything is emitted;
  /// * the app changes afterwards, so a gesture that reached nothing is reported
  ///   as [JigErrorCode.gestureNoEffect] instead of `ok`.
  ///
  /// The second one is the point. Where the finger actually went cannot be
  /// observed, so what is verified is that the app reacted - which is the same
  /// obligation `tap` meets by finding a live node that owns the action.
  static Future<Map<String, Object?>> swipe(
    JigSelector selector, {
    JigSwipeDirection direction = JigSwipeDirection.left,
    double fraction = 0.8,
    String? ref,
  }) async {
    // A ref is accepted here for the same reason the other acting verbs accept one:
    // when a scrollable exposes no key, label or type of its own, a handle from a
    // listing is the only way to name it - and pull-to-refresh is exactly that case.
    final element = (ref != null && ref.isNotEmpty)
        ? _findElementByRef(ref)
        : _findElement(selector);
    if (element == null) {
      throw JigActionFailure(
        ref != null && ref.isNotEmpty
            ? JigError(
                JigErrorCode.elementNotFound,
                'No widget owns $ref in the current frame',
                candidates: JigElementIndex.labels(),
                hint: 'Refs expire between frames; re-read them with jig tree.',
              )
            : _notFound(selector),
      );
    }
    final described = ref != null && ref.isNotEmpty ? ref : selector.describe();
    final box = element.renderObject;
    if (box is! RenderBox || !box.hasSize) {
      throw JigActionFailure(
        JigError(
          JigErrorCode.elementNotVisible,
          '$described has no box to drag',
          candidates: JigElementIndex.labels(),
          hint: 'A widget that is not painted cannot receive a pointer path.',
        ),
      );
    }

    final origin = box.localToGlobal(Offset.zero);
    final size = box.size;
    final center = origin + size.center(Offset.zero);
    // Derived from the element, never from the caller: the whole gesture scales
    // with the control instead of with a number somebody guessed.
    final extent = direction.isHorizontal ? size.width : size.height;
    final distance = extent * fraction;
    final end = center + direction.delta * distance;

    if (!_originReaches(box, center)) {
      throw JigActionFailure(
        JigError(
          JigErrorCode.elementNotVisible,
          '$described is covered at its centre, so the drag would '
          'start on whatever is on top of it',
          candidates: JigElementIndex.labels(),
          hint: 'Read jig tree to see what is reachable now; close the overlay '
              'and try again.',
        ),
      );
    }

    final before = _observableState();
    _dispatchPointerPath(center, end);
    await _settle();

    final after = _observableState();
    if (before.length == after.length && before.containsAll(after)) {
      throw JigActionFailure(
        JigError(
          JigErrorCode.gestureNoEffect,
          'The ${direction.name} swipe on $described changed nothing: '
          'no element appeared or disappeared, and no registered state reader moved',
          candidates: JigElementIndex.labels(),
          hint: 'Either the element does not act on this gesture, or the reveal it '
              'should produce is not observable. Register a reader with Jig.state '
              'to make the effect visible.',
        ),
      );
    }

    _record(
      'swipe',
      selector,
      extra: <String, Object?>{'direction': direction.name},
    );
    return <String, Object?>{
      'gesture': 'swipe',
      'direction': direction.name,
      'distance': distance,
    };
  }

  /// Whether a hit test at [point] reaches [target] or something inside it.
  ///
  /// The path runs from the root down to the deepest box that accepted the point,
  /// so walking up from each entry is how "the target is under this point" is
  /// distinguished from "an overlay is".
  static bool _originReaches(RenderBox target, Offset point) {
    final view = WidgetsBinding.instance.renderViews.firstOrNull;
    if (view == null) {
      return false;
    }
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, point, view.flutterView.viewId);
    for (final entry in result.path) {
      final hit = entry.target;
      if (hit is! RenderObject) {
        continue;
      }
      RenderObject? node = hit;
      while (node != null) {
        if (identical(node, target)) {
          return true;
        }
        node = node.parent;
      }
    }
    return false;
  }

  /// What a gesture could plausibly change, as a set of stable identities.
  ///
  /// Rendered keys catch a pane being revealed; state readers catch a callback that
  /// fired without touching the tree. Refs are deliberately absent: node ids churn
  /// between frames, and including them would make every swipe look effective.
  static Set<String> _observableState() {
    final state = <String>{
      for (final entry in JigStateRegistry.snapshot().entries)
        '${entry.key}=${entry.value.error ?? entry.value.value}',
    };
    return <String>{...JigElementIndex.renderedKeys(), ...state};
  }

  /// Emits the path: down, a run of moves, up.
  ///
  /// Timestamps are synthesised rather than slept on, so velocity-based recognisers
  /// see a real gesture while no frame is delayed by a fixed sleep. Each move
  /// carries its own `delta`: drag recognisers accumulate that field rather than
  /// differencing positions, so a move without it is a move of zero.
  static void _dispatchPointerPath(Offset from, Offset to) {
    const int steps = 12;
    const int pointer = 100;
    final binding = WidgetsBinding.instance;
    final view = binding.platformDispatcher.implicitView;
    if (view == null) {
      return;
    }
    final viewId = view.viewId;
    final start = DateTime.now().microsecondsSinceEpoch;
    Duration at(int step) => Duration(microseconds: start + step * 16 * 1000);

    binding.handlePointerEvent(
      PointerDownEvent(
        pointer: pointer,
        position: from,
        viewId: viewId,
        timeStamp: at(0),
      ),
    );
    var previous = from;
    for (var step = 1; step <= steps; step++) {
      final position = Offset.lerp(from, to, step / steps)!;
      binding.handlePointerEvent(
        PointerMoveEvent(
          pointer: pointer,
          position: position,
          delta: position - previous,
          viewId: viewId,
          timeStamp: at(step),
        ),
      );
      previous = position;
    }
    binding.handlePointerEvent(
      PointerUpEvent(
        pointer: pointer,
        position: to,
        viewId: viewId,
        timeStamp: at(steps + 1),
      ),
    );
  }

  /// Leaves the current route the way the platform back button does.
  ///
  /// [WidgetsBinding.handlePopRoute] is the entry point the physical button
  /// dispatches through, so `PopScope`/`canPop` are honoured, stacked modals are
  /// dismissed in the framework's own order, and an interception gate behaves
  /// exactly as it does for a user. Calling `Navigator.pop` would bypass all of
  /// that and pop a guarded screen anyway - a test that passes while the real
  /// button would not.
  static Future<Map<String, Object?>> back() async {
    final before = JigNavHistory.current;
    final popsBefore = JigNavHistory.popCount;
    // The analyzer marks this entry point as test-visible and protected. It is
    // used deliberately: it is the only path that runs the same interception a
    // user's back button runs, and the alternative - Navigator.pop - would pop a
    // guarded screen and report a success a real button would not produce.
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    final handled = await WidgetsBinding.instance.handlePopRoute();
    // The return value alone is not trustworthy: a route that refuses the pop
    // still answers `true` (`RoutePopDisposition.doNotPop`), so reporting it as a
    // success would be the silent lie this project exists to remove. What counts
    // is whether a route actually left the stack.
    if (!handled || JigNavHistory.popCount == popsBefore) {
      throw JigActionFailure(
        JigError(
          JigErrorCode.backRefused,
          'The app declined the back request: no route left the stack',
          hint: 'A PopScope guard intercepted it, or there is nothing left to '
              'pop. Read jig nav to see where you are.',
        ),
      );
    }
    // A pop animates: until it finishes, the outgoing route is still in the widget
    // and semantics trees. Reporting success before that leaves a caller acting on a
    // route it has already left - measured as an ELEMENT_AMBIGUOUS on the next call,
    // with the popped row's Dismissible still listed as a candidate. Every other verb
    // that changes what is rendered settles first; this one was the exception.
    await _settle();
    JigBus.instance.emit(JigSource.custom, 'back', <String, Object?>{
      'from': before,
      'route': JigNavHistory.current,
    });
    return <String, Object?>{
      'popped': true,
      'from': before,
      'route': JigNavHistory.current,
    };
  }

  /// Pages a scrollable until [selector] is reachable, and returns its handle.
  ///
  /// Each step performs the scrollable's own accessibility scroll action and
  /// waits a frame, inside the UI isolate. A host-side loop would be one round
  /// trip per step, and every trip is a chance to read state that has already
  /// moved.
  ///
  /// There are three exits and each says which one fired: found, budget spent, or
  /// the content ended (the rendered set stopped changing).
  static Future<Map<String, Object?>> scrollUntil(
    JigSelector selector, {
    bool horizontal = false,
    int steps = 20,
    String? within,
  }) async {
    // Direction is read off the node rather than assumed: at either end of the
    // content a scrollable advertises only the action that can move it, so a
    // fixed direction silently does nothing on a list sitting at an end.

    final already = refFor(selector);
    if (already != null) {
      // ensureVisible is the one-step path: the target is rendered, so paging
      // would move the list for no reason and change bounds that were correct.
      already.owner.performAction(already.node.id, SemanticsAction.showOnScreen);
      await _settle();
      _record(
        'scroll',
        selector,
        ref: already.ref,
        extra: <String, Object?>{'steps': 1},
      );
      return <String, Object?>{
        'ref': already.ref,
        'steps': 1,
        'reason': 'already-rendered',
      };
    }

    final named = within == null ? null : _scrollableNamed(within);
    if (within != null && named == null) {
      throw JigActionFailure(
        JigError(
          JigErrorCode.elementNotVisible,
          "'$within' does not resolve to a reachable "
          '${horizontal ? 'horizontal' : 'vertical'} scrollable',
          candidates: _scrollableCandidates(horizontal),
          hint: 'List what can be paged with jig tree --all, then pass its key '
              'to --in.',
        ),
      );
    }

    // Without --in, an unnamed choice is only safe when there is exactly one
    // scrollable: with two, paging the wrong one either does nothing or silently
    // loses the inner position.
    if (named == null) {
      final candidates = JigElementIndex.scrollables(horizontal: horizontal);
      if (candidates.isEmpty) {
        throw JigActionFailure(
          JigError(
            JigErrorCode.elementNotVisible,
            'No ${horizontal ? 'horizontal' : 'vertical'} scrollable is reachable '
            'right now',
            candidates: JigElementIndex.labels(),
            hint: 'A modal or another route is probably on top. Read jig tree to '
                'see what is reachable, then try again.',
          ),
        );
      }
      if (candidates.length > 1) {
        throw JigActionFailure(
          JigError(
            JigErrorCode.elementAmbiguous,
            '${candidates.length} scrollables could be paged',
            candidates: _scrollableCandidates(horizontal),
            hint: 'Name one with --in <key> or a ref from jig tree.',
          ),
        );
      }
    }

    var rendered = JigElementIndex.renderedKeys();
    // Which way this scrollable pages is discovered on the first step and then
    // kept. Re-deciding each step made the loop ping-pong: the forward action
    // would do nothing at the end, the reverse would move, and every step would
    // look like progress until the budget ran out.
    SemanticsAction? lockedAction;
    var lockedJump = false;
    var discovered = false;

    for (var step = 1; step <= steps; step++) {
      // Re-resolved each step: a rebuild can replace the scrollable's node, and
      // acting on a stale id would page nothing while looking like progress.
      final scrollable = (within == null ? null : _scrollableNamed(within)) ??
          _firstScrollable(horizontal);
      if (scrollable == null) {
        throw JigActionFailure(
          JigError(
            JigErrorCode.elementNotVisible,
            'The scrollable is no longer reachable',
            candidates: JigElementIndex.labels(),
            hint: 'jig tree',
          ),
        );
      }

      String? foundRef;
      var moved = false;
      if (!discovered) {
        final forward = _stepAction(
          scrollable.node,
          horizontal,
          preferForward: true,
        );
        final backward = _stepAction(
          scrollable.node,
          horizontal,
          preferForward: false,
        );
        final attempts = <SemanticsAction?>[
          ?forward,
          if (backward != null && backward != forward) backward,
          // Last resort: a viewport whose actions move nothing can still be
          // asked to jump to an offset it reports itself.
          null,
        ];
        for (final attempt in attempts) {
          final result = await _page(
            scrollable,
            horizontal,
            attempt,
            selector,
            rendered,
          );
          if (result.ref != null) {
            foundRef = result.ref;
            break;
          }
          if (result.moved) {
            moved = true;
            discovered = true;
            lockedAction = attempt;
            lockedJump = attempt == null;
            break;
          }
        }
      } else {
        final result = await _page(
          scrollable,
          horizontal,
          lockedJump ? null : lockedAction,
          selector,
          rendered,
        );
        foundRef = result.ref;
        moved = result.moved;
      }

      if (foundRef != null) {
        _record(
          'scroll',
          selector,
          ref: foundRef,
          extra: <String, Object?>{'steps': step},
        );
        return <String, Object?>{
          'ref': foundRef,
          'steps': step,
          'reason': 'found',
        };
      }

      if (!moved) {
        throw JigActionFailure(
          JigError(
            JigErrorCode.scrollExhausted,
            'The content ended after $step step(s) of a $steps-step budget: the '
            'scrollable stopped moving and ${selector.describe()} never appeared',
            candidates: JigElementIndex.labels(),
            hint: 'Nothing further in this direction. Read jig tree for the last '
                'rows.',
          ),
        );
      }
      rendered = JigElementIndex.renderedKeys();
    }

    throw JigActionFailure(
      JigError(
        JigErrorCode.scrollExhausted,
        'Budget of $steps step(s) spent without reaching ${selector.describe()}',
        candidates: JigElementIndex.labels(),
        hint: 'Raise --steps deliberately, or name the scrollable with --in.',
      ),
    );
  }

  /// The handle for [selector], or null when nothing is reachable.
  ///
  /// Differs from [isPresent] by returning the node a caller can act on next,
  /// which is what paging hands back once it finds its row.
  static ({String ref, SemanticsOwner owner, SemanticsNode node})? refFor(
    JigSelector selector,
  ) {
    if (selector.kind == SelectorKind.semantic ||
        selector.kind == SelectorKind.text) {
      final labelled = JigElementIndex.findByLabel(
        selector.value,
        exact: selector.exact,
      );
      if (labelled.matches != 1) {
        return null;
      }
      final node = labelled.node;
      final owner = labelled.owner;
      if (node == null || owner == null) {
        return null;
      }
      return (ref: 'n${node.id}', owner: owner, node: node);
    }
    final element = _findElement(selector);
    if (element == null) {
      return null;
    }
    final live = _liveActionableNode(element, SemanticsAction.tap) ??
        _liveActionableNode(element, SemanticsAction.longPress);
    if (live == null) {
      return null;
    }
    return (ref: 'n${live.node.id}', owner: live.owner, node: live.node);
  }

  /// The scrollable named by [within], accepting a key, a widget type or a label.
  ///
  /// Resolution is direction-agnostic on purpose: a scrollable advertises only
  /// the action that can currently move it, so looking for one particular action
  /// makes it "unreachable" the moment the list reaches an end. The step itself
  /// then picks from whatever the node does advertise.
  static ({SemanticsOwner owner, SemanticsNode node})? _scrollableNamed(
    String within,
  ) {
    if (within.startsWith('n') && int.tryParse(within.substring(1)) != null) {
      final resolved = JigElementIndex.resolveRef(within);
      return resolved != null && _isScrollable(resolved.node)
          ? (owner: resolved.owner, node: resolved.node)
          : null;
    }

    for (final selector in <JigSelector>[
      JigSelector.key(within),
      JigSelector.widgetType(within),
    ]) {
      final element = _findElement(selector);
      if (element == null) {
        continue;
      }
      final live = _scrollableFor(element);
      if (live != null) {
        return live;
      }
    }

    final labelled = JigElementIndex.findByLabel(within);
    var node = labelled.matches == 0 ? null : labelled.node;
    while (node != null && !_isScrollable(node)) {
      node = node.parent;
    }
    if (node == null) {
      return null;
    }
    final owner = JigElementIndex.ownerOf(node.id);
    return owner == null ? null : (owner: owner, node: node);
  }

  /// The scrollable that matches [element]'s own box.
  ///
  /// A nested scrollable is not always the node its element resolves to: a
  /// viewport can expose a container node and a separate node carrying the scroll
  /// actions, and the two differ in size. Matching the named widget's box against
  /// the candidate boxes picks the one the caller pointed at - the inner list for
  /// the inner key, the outer one for the outer key - instead of the first found.
  static ({SemanticsOwner owner, SemanticsNode node})? _scrollableFor(
    Element element,
  ) {
    final renderObject = element.renderObject;
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return _liveScrollableNode(element);
    }
    // Semantics rects arrive in device pixels while a render box measures in
    // logical ones, so both sides are brought into the same space before they are
    // compared. Mixing the two rejects the box the caller actually named.
    final dpr = WidgetsBinding
            .instance.platformDispatcher.views.firstOrNull?.devicePixelRatio ??
        1.0;
    final origin = renderObject.localToGlobal(Offset.zero) * dpr;
    final boxWidth = renderObject.size.width * dpr;
    final boxHeight = renderObject.size.height * dpr;
    final boxArea = boxWidth * boxHeight;

    final candidates = <({SemanticsOwner owner, SemanticsNode node})>[
      ...JigElementIndex.scrollables(horizontal: false),
      ...JigElementIndex.scrollables(horizontal: true),
    ];

    ({SemanticsOwner owner, SemanticsNode node})? best;
    var bestDelta = double.infinity;
    for (final candidate in candidates) {
      final rect = JigElementIndex.rectOf(candidate.node);
      final delta = (rect.width * rect.height - boxArea).abs();
      // A candidate must at least overlap the named widget: a scrollable
      // elsewhere on screen is not what the caller named.
      final overlaps = rect.x < origin.dx + boxWidth &&
          rect.x + rect.width > origin.dx &&
          rect.y < origin.dy + boxHeight &&
          rect.y + rect.height > origin.dy;
      if (!overlaps || delta >= bestDelta) {
        continue;
      }
      bestDelta = delta;
      best = candidate;
    }
    return best ?? _liveScrollableNode(element);
  }

  static bool _isScrollable(SemanticsNode node) {
    final data = node.getSemanticsData();
    return _kScrollActions.any(data.hasAction);
  }

  /// Nearest ancestor node that advertises any scroll action and is still live.
  static ({SemanticsOwner owner, SemanticsNode node})? _liveScrollableNode(
    Element element,
  ) {
    var renderObject = element.renderObject;
    while (renderObject != null) {
      final node = renderObject.debugSemantics;
      if (node != null && _isScrollable(node)) {
        final owner = JigElementIndex.ownerOf(node.id);
        if (owner != null) {
          return (owner: owner, node: node);
        }
      }
      renderObject = renderObject.parent;
    }
    return null;
  }

  static ({SemanticsOwner owner, SemanticsNode node})? _firstScrollable(
    bool horizontal,
  ) {
    final candidates = JigElementIndex.scrollables(horizontal: horizontal);
    return candidates.isEmpty ? null : candidates.first;
  }

  /// The action to page with, given which direction to prefer, or null when the
  /// node advertises no scroll action at all.
  ///
  /// Flutter advertises only the actions that can currently move a scrollable, and
  /// which of the pair means "further into the content" is not stable across
  /// widgets: a list sitting at its start advertises one, a nested viewport the
  /// other. So the loop asks for a preference and falls back to the other action
  /// when a step changes nothing.
  static SemanticsAction? _stepAction(
    SemanticsNode node,
    bool horizontal, {
    required bool preferForward,
  }) {
    final data = node.getSemanticsData();
    final forward =
        horizontal ? SemanticsAction.scrollLeft : SemanticsAction.scrollUp;
    final backward =
        horizontal ? SemanticsAction.scrollRight : SemanticsAction.scrollDown;
    if (preferForward && data.hasAction(forward)) {
      return forward;
    }
    if (data.hasAction(backward)) {
      return backward;
    }
    return data.hasAction(forward) ? forward : null;
  }

  /// Performs one page and reports what it achieved.
  ///
  /// A page is "moved" when the rendered set changed, and carries a [ref] when the
  /// target appeared. Both are read after the frame stream settles, so an animated
  /// page change is not mistaken for a stall.
  static Future<({String? ref, bool moved})> _page(
    ({SemanticsOwner owner, SemanticsNode node}) scrollable,
    bool horizontal,
    SemanticsAction? action,
    JigSelector selector,
    Set<String> rendered,
  ) async {
    if (action != null) {
      if (!scrollable.node.getSemanticsData().hasAction(action)) {
        return (ref: null, moved: false);
      }
      scrollable.owner.performAction(scrollable.node.id, action);
    } else if (!_jumpOnePage(scrollable.owner, scrollable.node, horizontal)) {
      return (ref: null, moved: false);
    }
    await _settle();

    final found = refFor(selector);
    if (found != null) {
      return (ref: found.ref, moved: true);
    }
    final now = JigElementIndex.renderedKeys();
    return (
      ref: null,
      moved: now.length != rendered.length || !now.containsAll(rendered),
    );
  }

  /// Jumps one viewport by asking the node to scroll to an offset it already
  /// reports.
  ///
  /// This is the fallback for viewports whose directional actions move nothing.
  /// The offset comes from the node's own `scrollPosition`/`scrollExtentMax`, so
  /// no caller arithmetic and no cached position is involved, and it is bounded by
  /// the content the node says it has.
  static bool _jumpOnePage(
    SemanticsOwner owner,
    SemanticsNode node,
    bool horizontal,
  ) {
    final data = node.getSemanticsData();
    if (!data.hasAction(SemanticsAction.scrollToOffset)) {
      return false;
    }
    final position = data.scrollPosition;
    final max = data.scrollExtentMax;
    if (position == null || max == null) {
      return false;
    }
    final min = data.scrollExtentMin ?? 0;
    final delta = horizontal ? node.rect.width : node.rect.height;
    if (delta <= 0) {
      return false;
    }
    final target = (position + delta).clamp(min, max).toDouble();
    if (target == position) {
      return false;
    }
    owner.performAction(
      node.id,
      SemanticsAction.scrollToOffset,
      // The framework's handler expects [dx, dy] as a Float64List, not an Offset.
      Float64List.fromList(
        horizontal ? <double>[target, 0] : <double>[0, target],
      ),
    );
    return true;
  }

  /// Waits for the frame stream to come to rest after an action.
  ///
  /// Two frames are enough for a scroll position that jumps, but a page change
  /// animates: reading the tree after the second frame sees the old page and calls
  /// a working scroll a stall. So this waits until no further frame is scheduled,
  /// with a ceiling so a continuously animating app cannot hang the command.
  static Future<void> _settle() async {
    final deadline = DateTime.now().add(const Duration(milliseconds: 800));
    await SchedulerBinding.instance.endOfFrame;
    var quiet = 0;
    while (DateTime.now().isBefore(deadline)) {
      await SchedulerBinding.instance.endOfFrame;
      if (SchedulerBinding.instance.hasScheduledFrame) {
        quiet = 0;
      } else {
        quiet++;
        if (quiet >= 2) {
          return;
        }
      }
    }
  }

  /// What can be paged, named the way a caller would name it.
  ///
  /// A key beats a label beats a ref: the hint says `--in <key>`, so listing refs
  /// alone would send the caller looking for something else.
  static List<String> _scrollableCandidates(bool horizontal) {
    final byRef = <String, JigElement>{
      for (final element in JigElementIndex.capture(limit: 400))
        element.ref: element,
    };
    return <String>[
      for (final candidate in JigElementIndex.scrollables(horizontal: horizontal))
        byRef['n${candidate.node.id}']?.key ??
            (candidate.node.getSemanticsData().label.isEmpty
                ? 'n${candidate.node.id}'
                : candidate.node.getSemanticsData().label),
    ];
  }


  ///
  /// Actionability, not existence: a covered widget is still in the element
  /// tree, so a wait that answers "the widget exists" would return while the
  /// very next `tap` fails. Waiting must be the way to wait for the action.
  static bool isPresent(JigSelector selector) {
    if (selector.kind == SelectorKind.semantic ||
        selector.kind == SelectorKind.text) {
      return JigElementIndex.findByLabel(
            selector.value,
            exact: selector.exact,
          ).matches >
          0;
    }
    final element = _findElement(selector);
    if (element == null) {
      return false;
    }
    return _liveActionableNode(element, SemanticsAction.tap) != null ||
        _liveActionableNode(element, SemanticsAction.longPress) != null;
  }

  /// The widget whose semantics node [ref] names.
  ///
  /// The inverse of the listing: a ref is a node id, and a drag needs the render box
  /// that node belongs to. Walking for it is cheap because the caller already paid
  /// for the listing that produced the ref.
  static Element? _findElementByRef(String ref) {
    final resolved = JigElementIndex.resolveRef(ref);
    if (resolved == null) {
      return null;
    }
    // A node's owner is not always the element whose render object produced it: a
    // scrollable's actioned node is created below every element that names it. When no
    // element claims the id, the rectangle does - a drag only needs the box.
    return JigElementIndex.elementForNode(resolved.node.id) ??
        JigElementIndex.elementForRect(JigElementIndex.rectOf(resolved.node));
  }

  static Element? _findElement(JigSelector selector) {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) {
      return null;
    }
    final matches = <Element>[];
    void visit(Element element) {
      if (_matches(element, selector)) {
        matches.add(element);
      }
      element.visitChildren(visit);
    }

    visit(root);
    if (matches.isEmpty) {
      return null;
    }
    final index = selector.kind == SelectorKind.widgetType ? selector.index : 0;
    return index < matches.length ? matches[index] : null;
  }

  static EditableTextState? _findEditableText(JigSelector selector) {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) {
      return null;
    }
    final matches = <EditableTextState>[];
    void visit(Element element) {
      final widget = element.widget;
      if (widget is EditableText && element is StatefulElement) {
        final state = element.state;
        if (state is EditableTextState) {
          if (selector.kind == SelectorKind.key ||
              selector.kind == SelectorKind.widgetType ||
              _nearbyLabel(element, selector)) {
            matches.add(state);
          }
        }
      }
      element.visitChildren(visit);
    }

    visit(root);
    return matches.isEmpty ? null : matches.first;
  }

  /// Whether an ancestor of [element] shows the label the caller asked for.
  ///
  /// Text fields render their decoration label *beside* the editable, not above
  /// it in the element tree, so walking ancestors is not enough: the nearest
  /// ancestor whose subtree carries the text is the field the caller meant.
  static bool _nearbyLabel(Element element, JigSelector selector) {
    final needle = selector.value.toLowerCase();
    var found = false;
    element.visitAncestorElements((Element ancestor) {
      found = _labelInSubtree(ancestor, needle, 4);
      return !found;
    });
    return found;
  }

  static bool _labelInSubtree(Element element, String needle, int depth) {
    final widget = element.widget;
    if (widget is Text) {
      final data = (widget.data ?? widget.textSpan?.toPlainText() ?? '');
      if (data.toLowerCase().contains(needle)) {
        return true;
      }
    } else if (widget is Semantics) {
      final label = widget.properties.label ?? '';
      if (label.toLowerCase().contains(needle)) {
        return true;
      }
    }
    if (depth == 0) {
      return false;
    }
    var found = false;
    element.visitChildren((Element child) {
      if (!found) {
        found = _labelInSubtree(child, needle, depth - 1);
      }
    });
    return found;
  }

  static bool _matches(Element element, JigSelector selector) {
    final widget = element.widget;
    switch (selector.kind) {
      case SelectorKind.key:
        final key = widget.key;
        if (key == null) {
          return false;
        }
        if (key is ValueKey<Object?>) {
          return key.value.toString() == selector.value;
        }
        return key.toString().contains(selector.value);
      case SelectorKind.widgetType:
        return widget.runtimeType.toString() == selector.value;
      case SelectorKind.text:
        if (widget is Text) {
          final plain = widget.data ?? widget.textSpan?.toPlainText() ?? '';
          return plain == selector.value;
        }
        if (widget is EditableText) {
          return widget.controller.text == selector.value;
        }
        return false;
      case SelectorKind.semantic:
        return false;
    }
  }

  static JigError _notFound(JigSelector selector) => JigError(
        JigErrorCode.elementNotFound,
        'Nothing matches ${selector.describe()}',
        candidates: JigElementIndex.labels(),
        hint: 'jig tree',
      );

  static void _record(
    String verb,
    JigSelector selector, {
    String? ref,
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    JigBus.instance.emit(JigSource.custom, verb, <String, Object?>{
      // `selector` is the sentence error messages quote and existing consumers
      // read; `selectorSpec` is the same choice in a form a recorder can replay.
      // Both, because reshaping the first would be a breaking change for no gain.
      'selector': selector.describe(),
      'selectorSpec': selector.toJson(),
      'ref': ?ref,
      ...extra,
    });
  }
}

/// Turns a label search into either a usable match or the right typed failure.
extension on ({
  SemanticsOwner? owner,
  SemanticsNode? node,
  int matches,
  List<String> labels,
}) {
  ({SemanticsOwner owner, SemanticsNode node})? nodeOrNull(
    JigSelector selector,
  ) {
    if (matches > 1) {
      throw JigActionFailure(
        JigError(
          JigErrorCode.elementAmbiguous,
          '$matches elements match ${selector.describe()}',
          candidates: labels,
          hint: 'Narrow it with --key, or act on a ref from jig tree.',
        ),
      );
    }
    final matchedNode = node;
    final matchedOwner = owner;
    if (matches == 0 || matchedNode == null || matchedOwner == null) {
      return null;
    }
    return (owner: matchedOwner, node: matchedNode);
  }
}
