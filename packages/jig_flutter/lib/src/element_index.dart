import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:jig_protocol/jig_protocol.dart';

/// What a listed node can be selected by, read off the widget that owns it.
typedef _Owner = ({String? key, String? ownerType, bool nameable});

/// Widgets that only wrap, decorate or lay out. Naming one tells a caller
/// nothing it can select with, so the search walks past them to the widget the
/// app actually chose.
const Set<String> _kTransparent = <String>{
  'Semantics',
  'MergeSemantics',
  'ExcludeSemantics',
  'InkWell',
  'InkResponse',
  'Ink',
  'GestureDetector',
  'Focus',
  'Material',
  'Card',
  'Padding',
  'Align',
  'Center',
  'ConstrainedBox',
  'SizedBox',
  'DecoratedBox',
  'ColoredBox',
  'SafeArea',
  'MediaQuery',
  'Directionality',
  'IconTheme',
  'DefaultTextStyle',
  'AnimatedDefaultTextStyle',
  'ScrollConfiguration',
  'PrimaryScrollController',
  'NotificationListener',
  'Localizations',
  'RepaintBoundary',
  'AbsorbPointer',
  'IgnorePointer',
  'Listener',
  'MouseRegion',
  'Tooltip',
  'KeyedSubtree',
  'Builder',
  'AutomaticKeepAlive',
  'KeepAlive',
  // Layout and painting wrappers. A caller cannot select by any of these, and
  // several of them sit between a container node and the control inside it.
  'PhysicalShape',
  'PhysicalModel',
  'CustomPaint',
  'ClipRRect',
  'ClipRect',
  'ClipOval',
  'Opacity',
  'Transform',
  'RotatedBox',
  'FittedBox',
  'AspectRatio',
  'FractionallySizedBox',
  'SizedOverflowBox',
  'OverflowBox',
  'LimitedBox',
  'UnconstrainedBox',
  'IntrinsicHeight',
  'IntrinsicWidth',
  'Expanded',
  'Flexible',
  'Positioned',
  'Offstage',
  'TickerMode',
  'Visibility',
  'Hero',
  'AnimatedBuilder',
  'AnimatedContainer',
  'AnimatedPadding',
  'AnimatedOpacity',
  'AnimatedSwitcher',
  'LayoutBuilder',
  'StatefulBuilder',
  'CustomSingleChildLayout',
};

/// The actions worth reporting to an agent. Enumerating all of them by hand is
/// required because [SemanticsAction] exposes no `values` list.
const List<SemanticsAction> _kReportedActions = <SemanticsAction>[
  SemanticsAction.tap,
  SemanticsAction.longPress,
  SemanticsAction.scrollLeft,
  SemanticsAction.scrollRight,
  SemanticsAction.scrollUp,
  SemanticsAction.scrollDown,
  SemanticsAction.scrollToOffset,
  SemanticsAction.increase,
  SemanticsAction.decrease,
  SemanticsAction.setText,
  SemanticsAction.setSelection,
  SemanticsAction.dismiss,
  SemanticsAction.focus,
  SemanticsAction.expand,
  SemanticsAction.collapse,
];

/// A semantics tree, together with the owner that can act on it.
typedef _Tree = ({SemanticsOwner owner, SemanticsNode root});

/// Builds the list an agent selects from, out of the accessibility tree.
///
/// The semantics tree is used instead of a widget-tree walk because it is the
/// framework's own answer to "what can be acted on, and what is it called". It is
/// already computed for the current frame, and it is unaffected by whatever a
/// router or a snackbar queue happens to insert above the route.
///
/// Trees are looked up from each [RenderView]'s pipeline owner rather than from
/// [RendererBinding.rootPipelineOwner]: the semantics owner is created on the
/// view's owner, and the root owner reports an owner with no root node - which
/// reads as "semantics are off" when they are not.
abstract final class JigElementIndex {
  static List<JigElement> capture({
    bool interactiveOnly = true,
    bool includeValues = true,
    int maxDepth = 48,
    int limit = 400,
  }) {
    final out = <JigElement>[];
    final owners = _owners();
    for (final tree in _trees()) {
      void visit(SemanticsNode node, int depth) {
        if (depth > maxDepth || out.length >= limit) {
          return;
        }
        final element = _describe(
          node,
          depth,
          interactiveOnly,
          includeValues,
          owners,
        );
        if (element != null) {
          out.add(element);
        }
        node.visitChildren((SemanticsNode child) {
          visit(child, depth + 1);
          return true;
        });
      }

      visit(tree.root, 0);
      if (out.length >= limit) {
        break;
      }
    }
    return out;
  }

  /// The node behind a ref emitted by [capture], plus the owner able to act on it.
  static ({SemanticsOwner owner, SemanticsNode node})? resolveRef(String ref) {
    if (!ref.startsWith('n')) {
      return null;
    }
    final id = int.tryParse(ref.substring(1));
    if (id == null) {
      return null;
    }
    for (final tree in _trees()) {
      SemanticsNode? found;
      _walk(tree.root, (SemanticsNode node) {
        if (node.id == id) {
          found ??= node;
        }
      });
      final hit = found;
      if (hit != null) {
        return (owner: tree.owner, node: hit);
      }
    }
    return null;
  }

  /// First node whose label matches [label]. Reports how many matched, so a caller
  /// can tell "not found" from "ambiguous".
  static ({
    SemanticsOwner? owner,
    SemanticsNode? node,
    int matches,
    List<String> labels,
  }) findByLabel(String label, {bool exact = true}) {
    final needle = _normalise(label);
    SemanticsOwner? owner;
    SemanticsNode? first;
    var matches = 0;
    final labels = <String>[];

    for (final tree in _trees()) {
      _walk(tree.root, (SemanticsNode node) {
        final haystack = _normalise(node.getSemanticsData().label);
        if (haystack.isEmpty) {
          return;
        }
        final hit = exact ? haystack == needle : haystack.contains(needle);
        if (!hit) {
          return;
        }
        matches++;
        if (labels.length < 8 && !labels.contains(haystack)) {
          labels.add(haystack);
        }
        if (first == null) {
          first = node;
          owner = tree.owner;
        }
      });
    }

    return (owner: owner, node: first, matches: matches, labels: labels);
  }

  /// The owner that produced the node with [id].
  ///
  /// Needed because a [SemanticsNode] does not point back at its owner, and
  /// [SemanticsOwner.performAction] must be called on the right one.
  static SemanticsOwner? ownerOf(int id) {
    for (final tree in _trees()) {
      var found = false;
      _walk(tree.root, (SemanticsNode node) {
        if (node.id == id) {
          found = true;
        }
      });
      if (found) {
        return tree.owner;
      }
    }
    return null;
  }

  /// Labels currently reachable, for "did you mean" lists.
  static List<String> labels({int limit = 8}) {
    final out = <String>[];
    for (final element in capture(limit: limit * 4)) {
      final label = element.label;
      if (label != null && label.isNotEmpty && !out.contains(label)) {
        out.add(label);
        if (out.length >= limit) {
          break;
        }
      }
    }
    return out;
  }

  /// Why the index is empty, when it is.
  ///
  /// A harness that reports "0 elements" without saying whether semantics are off,
  /// the tree has no root, or the root simply has no actionable children forces
  /// the caller to guess - which is the failure mode this project exists to
  /// remove, so it applies to its own diagnostics first.
  static Map<String, Object?> diagnostics() {
    final trees = _trees();
    var nodeCount = 0;
    var actionableCount = 0;
    for (final tree in trees) {
      _walk(tree.root, (SemanticsNode node) {
        nodeCount++;
        if (node.getSemanticsData().actions != 0) {
          actionableCount++;
        }
      });
    }

    return <String, Object?>{
      'semanticsEnabled': SemanticsBinding.instance.semanticsEnabled,
      'handles': SemanticsBinding.instance.debugOutstandingSemanticsHandles,
      'views': RendererBinding.instance.renderViews.length,
      'trees': trees.length,
      'nodeCount': nodeCount,
      'actionableCount': actionableCount,
    };
  }

  /// Every semantics tree in the app, one per view.
  static List<_Tree> _trees() {
    final out = <_Tree>[];
    void add(SemanticsOwner? owner) {
      final root = owner?.rootSemanticsNode;
      if (owner == null || root == null) {
        return;
      }
      for (final tree in out) {
        if (identical(tree.owner, owner)) {
          return;
        }
      }
      out.add((owner: owner, root: root));
    }

    for (final view in RendererBinding.instance.renderViews) {
      add(view.owner?.semanticsOwner);
    }
    add(RendererBinding.instance.rootPipelineOwner.semanticsOwner);
    return out;
  }

  static void _walk(SemanticsNode node, void Function(SemanticsNode) visit) {
    visit(node);
    node.visitChildren((SemanticsNode child) {
      _walk(child, visit);
      return true;
    });
  }

  static JigElement? _describe(
    SemanticsNode node,
    int depth,
    bool interactiveOnly,
    bool includeValues,
    Map<int, _Owner> owners,
  ) {
    final data = node.getSemanticsData();
    final actions = <String>[
      for (final action in _kReportedActions)
        if (data.hasAction(action)) action.name,
    ];
    final label = data.label;
    final value = data.value;
    final hint = data.hint;

    final owner = owners[node.id];
    // A key is a name the caller chose, so a node it names stays addressable even when
    // it does nothing itself: a `ListView`'s scroll node carries the actions, but the
    // widget the caller keyed is the boundary just above it.
    final named = owner?.key != null;
    if (interactiveOnly && actions.isEmpty && !named) {
      return null;
    }
    if (!interactiveOnly && actions.isEmpty && label.isEmpty && value.isEmpty && !named) {
      return null;
    }

    return JigElement(
      ref: 'n${node.id}',
      kind: 'semantics',
      label: label.isEmpty ? null : label,
      value: includeValues && value.isNotEmpty ? value : null,
      hint: hint.isEmpty ? null : hint,
      key: owner?.key,
      ownerType: owner?.ownerType,
      rect: rectOf(node),
      actions: actions,
      depth: depth,
    );
  }

  /// Inverts the element-to-node mapping that acting already walks.
  ///
  /// A semantics node is often owned by a *container* rather than by the control
  /// a caller means: `Card` wraps its child in `Semantics(container: true)`, so
  /// the node belongs to the card while the widget that carries the key and the
  /// tap is the `ListTile` inside it. Walking elements instead of nodes - each
  /// one up to the nearest node it resolves to - reports the shallowest widget a
  /// caller could name, and that is the one whose key matters.
  ///
  /// Pre-order traversal means the first element that resolves to a node is the
  /// shallowest one, so the first write wins.
  static Map<int, _Owner> _owners() {
    final out = <int, _Owner>{};
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) {
      return out;
    }
    // Ancestor walks repeat the same render objects; remembering each answer keeps
    // this linear in the tree instead of quadratic.
    final resolved = <RenderObject, SemanticsNode?>{};
    final keyed = <({int nodeId, String key, String ownerType})>[];

    void visit(Element element) {
      final node = _resolveNode(element.renderObject, resolved);
      if (node != null) {
        // Generic instantiations print as `NotificationListener<KeepAliveNotification>`,
        // so the base name is what identifies the widget for both the transparency
        // check and the report.
        final ownerType = element.widget.runtimeType.toString().split('<').first;
        // `*Semantics` widgets are accessibility plumbing: naming one tells a
        // caller nothing it can select with.
        final nameable = !ownerType.startsWith('_') &&
            !ownerType.endsWith('Semantics') &&
            !_kTransparent.contains(ownerType);
        final existing = out[node.id];
        if (nameable && (existing == null || !existing.nameable)) {
          out[node.id] = (
            key: _keyOf(element),
            ownerType: ownerType,
            nameable: true,
          );
        } else if (existing == null) {
          // Recorded only so a node with nothing nameable still says something.
          out[node.id] = (key: null, ownerType: ownerType, nameable: false);
        }
        final key = _keyOf(element);
        // `ValueKey(_ScaffoldSlot.appBar)` is framework plumbing, not a name a caller
        // can pass back.
        if (key != null && !key.startsWith('_')) {
          // A key belongs to the widget that carries it, and that widget's node is
          // often produced by a render object *below* it: a `Slider` builds the
          // object that advertises `increase`, a `ListView`'s viewport sits under a
          // `Scrollable`. The upward walk above answers "which node does this render
          // object belong to", which for those widgets is an ancestor's node - so
          // attributing here would name the wrong element, and refraining names none.
          final own = _nodeBelow(element);
          if (own != null) {
            keyed.add((nodeId: own, key: key, ownerType: ownerType));
          }
        }
      }
      element.visitChildren(visit);
    }

    visit(root);

    // A key is the contract's most stable selector, so a widget that carries one
    // names its node even where a wrapper would otherwise win. Pre-order means the
    // last writer is the deepest keyed widget, which is the one a caller means.
    // A widget's node and the node that can act on it are not always the same one: a
    // `ListView`'s key lands on a boundary with no actions while the scroll actions
    // live on a node covering the identical rectangle, and a `Slider` splits the same
    // way. Occupying the same box is what ties them together, so a key moves to the
    // actioned node when they share one - a name that cannot act is not a selector.
    final rectOfNode = <int, String>{};
    final actionedByRect = <String, int>{};
    for (final tree in _trees()) {
      _walk(tree.root, (SemanticsNode node) {
        final rect = rectOf(node);
        final signature = '${rect.x.round()},${rect.y.round()},'
            '${rect.width.round()},${rect.height.round()}';
        rectOfNode[node.id] = signature;
        if (node.getSemanticsData().actions != 0) {
          actionedByRect.putIfAbsent(signature, () => node.id);
        }
      });
    }

    for (final entry in keyed) {
      final signature = rectOfNode[entry.nodeId];
      final actioned = signature == null ? null : actionedByRect[signature];
      out[actioned ?? entry.nodeId] = (
        key: entry.key,
        ownerType: entry.ownerType,
        nameable: true,
      );
    }
    return out;
  }

  /// The shallowest node inside [element]'s own subtree, if it has one.
  ///
  /// Pre-order and depth-bounded: the first match is the widget itself when it draws
  /// a node, which is the common case, and something it builds when it does not.
  static int? _nodeBelow(Element element) {
    // Nodes hang off render objects, so only `RenderObjectElement`s can own one.
    // Reading `element.renderObject` instead would not work: for a composed widget it
    // returns the *first descendant* render object, and a `ListView`'s scrollable node
    // is owned by a gesture handler that sits above the viewport it descends to.
    int? found;
    void visit(Element candidate, int depth) {
      if (found != null || depth > 64) {
        return;
      }
      if (candidate is RenderObjectElement) {
        final node = candidate.renderObject.debugSemantics;
        if (node != null) {
          found = node.id;
          return;
        }
      }
      candidate.visitChildren((Element child) => visit(child, depth + 1));
    }

    visit(element, 0);
    return found;
  }

  /// The deepest box whose painted rect is [rect], within a device pixel.
  ///
  /// Reachable nodes do not always have an owner: a scrollable's actioned node is
  /// created by a render object below every element that carries a key, so the only
  /// thing tying the two together is the rectangle they both occupy.
  static Element? elementForRect(JigRect rect) {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) {
      return null;
    }
    // [JigRect] is the semantics tree's unit, which is physical pixels; a box reports
    // logical ones.
    final scale = WidgetsBinding
            .instance
            .platformDispatcher
            .implicitView
            ?.devicePixelRatio ??
        1.0;
    Element? found;
    void visit(Element element) {
      if (element is RenderObjectElement) {
        final box = element.renderObject;
        if (box is RenderBox && box.hasSize) {
          final at = box.localToGlobal(Offset.zero) & box.size;
          if ((at.left * scale - rect.x).abs() <= 1 &&
              (at.top * scale - rect.y).abs() <= 1 &&
              (at.width * scale - rect.width).abs() <= 1 &&
              (at.height * scale - rect.height).abs() <= 1) {
            found = element;
          }
        }
      }
      element.visitChildren(visit);
    }

    visit(root);
    return found;
  }

  /// The shallowest widget whose own node is [id].
  ///
  /// The inverse of the listing, for verbs that act on a handle: a drag needs the
  /// render box the node belongs to, and a scrollable's node is produced by a render
  /// object the caller's keyed widget builds below itself.
  static Element? elementForNode(int id) {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) {
      return null;
    }
    final resolved = <RenderObject, SemanticsNode?>{};
    Element? found;
    void visit(Element element) {
      if (found != null) {
        return;
      }
      if (_resolveNode(element.renderObject, resolved)?.id == id) {
        found = element;
        return;
      }
      element.visitChildren(visit);
    }

    visit(root);
    return found;
  }

  /// The nearest node this render object, or an ancestor of it, produced.
  static SemanticsNode? _resolveNode(
    RenderObject? renderObject,
    Map<RenderObject, SemanticsNode?> cache,
  ) {
    final chain = <RenderObject>[];
    var current = renderObject;
    SemanticsNode? found;
    while (current != null) {
      if (cache.containsKey(current)) {
        found = cache[current];
        break;
      }
      chain.add(current);
      final node = current.debugSemantics;
      if (node != null) {
        found = node;
        break;
      }
      current = current.parent;
    }
    for (final link in chain) {
      cache[link] = found;
    }
    return found;
  }

  static String? _keyOf(Element element) {
    final key = element.widget.key;
    // Only a ValueKey carries something a caller can pass back. Framework
    // internals carry GlobalKeys whose string form ("[GlobalKey#2a08b ink
    // renderer]") is not a selector, and reporting it would bury the real one.
    if (key is ValueKey<Object?>) {
      return key.value?.toString();
    }
    return null;
  }

  /// Bounds in screen coordinates.
  ///
  /// [SemanticsNode.rect] is local to the node's coordinate system, so the
  /// transform chain up to the root is applied here. Reading the local rect alone
  /// would report the same bounds at every scroll offset.
  static JigRect rectOf(SemanticsNode node) {
    var rect = node.rect;
    SemanticsNode? current = node;
    while (current != null) {
      final transform = current.transform;
      if (transform != null) {
        rect = MatrixUtils.transformRect(transform, rect);
      }
      current = current.parent;
    }
    return JigRect(
      x: rect.left,
      y: rect.top,
      width: rect.width,
      height: rect.height,
    );
  }

  /// Every node that advertises a scroll action on [horizontal]'s axis.
  ///
  /// Used by paging: the scrollable advertises its own accessibility scroll, and
  /// performing that action is the only way to move it without a pointer path.
  static List<({SemanticsOwner owner, SemanticsNode node})> scrollables({
    required bool horizontal,
  }) {
    final out = <({SemanticsOwner owner, SemanticsNode node})>[];
    for (final tree in _trees()) {
      _walk(tree.root, (SemanticsNode node) {
        final data = node.getSemanticsData();
        final matches = horizontal
            ? data.hasAction(SemanticsAction.scrollLeft) ||
                data.hasAction(SemanticsAction.scrollRight)
            : data.hasAction(SemanticsAction.scrollUp) ||
                data.hasAction(SemanticsAction.scrollDown);
        if (matches) {
          out.add((owner: tree.owner, node: node));
        }
      });
    }
    return out;
  }

  /// Identity of what is rendered right now, used to tell a stalled scroll from a
  /// page that merely repeated a row.
  ///
  /// Only stable identities count. A ref is a node id, and ids churn between
  /// frames even when nothing moved, so including one makes a static list look
  /// like it is scrolling forever and the stall is never detected.
  static Set<String> renderedKeys({int limit = 200}) {
    return <String>{
      for (final element in capture(limit: limit))
        if ((element.key ?? element.label) case final String identity) identity,
    };
  }

  static String _normalise(String? raw) =>
      (raw ?? '').replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
}
