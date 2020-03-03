import 'package:inday/stela/interfaces/element.dart';
import 'package:inday/stela/interfaces/location.dart';
import 'package:inday/stela/interfaces/node.dart';
import 'package:inday/stela/interfaces/operation.dart';
import 'package:inday/stela/interfaces/path.dart';
import 'package:inday/stela/interfaces/path_ref.dart';
import 'package:inday/stela/interfaces/point.dart';
import 'package:inday/stela/interfaces/point_ref.dart';
import 'package:inday/stela/interfaces/range.dart';
import 'package:inday/stela/interfaces/range_ref.dart';
import 'package:inday/stela/interfaces/text.dart';

Expando<List<Path>> dirtyPaths = Expando();
// Expando<bool> _flushing = Expando();
Expando<bool> _normalizing = Expando();
Expando<Set<PathRef>> _pathRefs = Expando();
Expando<Set<PointRef>> _pointRefs = Expando();
Expando<Set<RangeRef>> _rangeRefs = Expando();

/// The `Editor` interface stores all the state of a Stela editor. It is extended
/// by plugins that wish to add their own helpers and implement new behaviors.
class Editor implements Ancestor {
  Editor(
      {this.children = const <Node>[],
      this.selection,
      this.operations,
      this.marks});

  /// The `children` property contains the document tree of nodes that make up the editor's content
  List<Node> children;

  /// The `selection` property contains the user's current selection, if any
  Range selection;

  /// The `operations` property contains all of the operations that have been applied since the last "change" was flushed. (Since Slate batches operations up into ticks of the event loop.)
  List<Operation> operations;

  /// The `marks` property stores formatting that is attached to the cursor, and that will be applied to the text that is inserted next
  Map<String, dynamic> marks;

  // Schema-specific node behaviors.
  bool Function(Element element) isInline;
  bool Function(Element element) isVoid;
  void Function(NodeEntry entry) normalizeNode;
  void Function() onChange;

  // Overrideable core actions.
  void Function(String key, dynamic value) addMark;
  void Function(Operation op) apply;
  void Function(Unit unit) deleteBackward;
  void Function(Unit unit) deleteForward;
  void Function() deleteFragment;
  void Function() insertBreak;
  void Function(List<Node> fragment) insertFragment;
  void Function(Node node) insertNode;
  void Function(String text) insertText;
  void Function(String key) removeMark;
}

typedef NodeMatch<T extends Node> = bool Function(Node node);

enum Mode { all, highest, lowest }

enum Unit {
  offset,
  character,
  word,
  line,
  block,
}

enum Edge { start, end }

class EditorUtils {
  /// Get the ancestor above a location in the document.
  static NodeEntry<T> above<T extends Ancestor>(Editor editor,
      {Location at,
      NodeMatch<T> match,
      Mode mode = Mode.lowest,
      bool voids = false}) {
    at = at ?? editor.selection;

    if (at == null) {
      return null;
    }

    Path path = EditorUtils.path(editor, at);
    bool reverse = mode == Mode.lowest;

    for (NodeEntry entry in EditorUtils.levels(editor,
        at: path, voids: voids, match: match, reverse: reverse)) {
      Node n = entry.node;
      Path p = entry.path;

      if (!(n is Text) && !PathUtils.equals(path, p)) {
        return NodeEntry(n, p);
      }
    }
  }

  /// Add a custom property to the leaf text nodes in the current selection.
  ///
  /// If the selection is currently collapsed, the marks will be added to the
  /// `editor.marks` property instead, and applied when text is inserted next.
  static void addMark(Editor editor, String key, dynamic value) {
    editor.addMark(key, value);
  }

  /// Get the point after a location.
  static Point after(Editor editor, Location at,
      {int distance = 1, Unit unit}) {
    Point anchor = EditorUtils.point(editor, at, edge: Edge.end);
    Point focus = EditorUtils.end(editor, Path([]));
    Range range = Range(anchor, focus);
    int d = 0;
    Point target;

    for (Point p in EditorUtils.positions(editor, at: range, unit: unit)) {
      if (d > distance) {
        break;
      }

      if (d != 0) {
        target = p;
      }

      d++;
    }

    return target;
  }

  /// Get the point before a location.
  static Point before(
    Editor editor,
    Location at, {
    int distance = 1,
    Unit unit,
  }) {
    Point anchor = EditorUtils.start(editor, Path([]));
    Point focus = EditorUtils.point(editor, at, edge: Edge.start);
    Range range = Range(anchor, focus);

    int d = 0;
    Point target;

    for (Point p in EditorUtils.positions(editor,
        at: range, reverse: true, unit: unit)) {
      if (d > distance) {
        break;
      }

      if (d != 0) {
        target = p;
      }

      d++;
    }

    return target;
  }

  /// Delete content in the editor backward from the current selection.
  static void deleteBackward(Editor editor, {Unit unit = Unit.character}) {
    editor.deleteBackward(unit);
  }

  /// Delete content in the editor forward from the current selection.
  static void deleteForward(Editor editor, {Unit unit = Unit.character}) {
    editor.deleteForward(unit);
  }

  /// Delete the content in the current selection.
  static void deleteFragment(Editor editor) {
    editor.deleteFragment();
  }

  /// Get the start and end points of a location.
  static Edges edges(Editor editor, Location at) {
    return Edges(EditorUtils.start(editor, at), EditorUtils.end(editor, at));
  }

  /// Get the end point of a location.
  static Point end(Editor editor, Location at) {
    return EditorUtils.point(editor, at, edge: Edge.end);
  }

  /// Get the first node at a location.
  static NodeEntry first(Editor editor, Location at) {
    Path path = EditorUtils.path(editor, at, edge: Edge.start);
    return EditorUtils.node(editor, path);
  }

  /// Get the fragment at a location.
  static List<Descendant> fragment(Editor editor, Location at) {
    Range range = EditorUtils.range(editor, at, null);
    List<Descendant> fragment = NodeUtils.fragment(editor, range);
    return fragment;
  }

  /// Check if a node has block children.
  static bool hasBlocks(Editor editor, Element element) {
    bool hasBlocks = false;

    for (Node node in element.children) {
      if (EditorUtils.isBlock(editor, node)) {
        hasBlocks = true;
        break;
      }
    }

    return hasBlocks;
  }

  /// Check if a node has inline and text children.
  static bool hasInlines(Editor editor, Element element) {
    bool hasInlines = false;

    for (Node node in element.children) {
      if (node is Text || EditorUtils.isInline(editor, node)) {
        hasInlines = true;
        break;
      }
    }

    return hasInlines;
  }

  /// Check if a node has text children.
  static bool hasTexts(Editor editor, Element element) {
    bool hasTexts = false;

    for (Node node in element.children) {
      if (node is Text) {
        hasTexts = true;
        break;
      }
    }

    return hasTexts;
  }

  /// Insert a block break at the current selection.
  ///
  /// If the selection is currently expanded, it will be deleted first.
  static void insertBreak(Editor editor) {
    editor.insertBreak();
  }

  /// Insert a fragment at the current selection.
  ///
  /// If the selection is currently expanded, it will be deleted first.
  static void insertFragment(Editor editor, List<Node> fragment) {
    editor.insertFragment(fragment);
  }

  /// Insert a node at the current selection.
  ///
  /// If the selection is currently expanded, it will be deleted first.
  static void insertNode(Editor editor, Node node) {
    editor.insertNode(node);
  }

  /// Insert text at the current selection.
  ///
  /// If the selection is currently expanded, it will be deleted first.
  static void insertText(Editor editor, String text) {
    editor.insertText(text);
  }

  /// Check if a value is a block `Element` object.
  static bool isBlock(Editor editor, Node node) {
    return (node is Element) && !editor.isInline(node);
  }

  /// Check if a point is the end point of a location.

  static bool isEnd(Editor editor, Point point, Location at) {
    Point end = EditorUtils.end(editor, at);
    return PointUtils.equals(point, end);
  }

  /// Check if a point is an edge of a location.
  static bool isEdge(Editor editor, Point point, Location at) {
    return EditorUtils.isStart(editor, point, at) ||
        EditorUtils.isEnd(editor, point, at);
  }

  /// Check if an element is empty, accounting for void nodes.
  static bool isEmpty(Editor editor, Element element) {
    List<Node> children = element.children;
    Node first = children[0];
    return (children.length == 0 ||
        (children.length == 1 &&
            (first is Text) &&
            first.text == '' &&
            !editor.isVoid(element)));
  }

  /// Check if a value is an inline `Element` object.
  static bool isInline(Editor editor, Node node) {
    return (node is Element) && editor.isInline(node);
  }

  /// Check if the editor is currently _normalizing after each operation.
  static bool isNormalizing(Editor editor) {
    bool isNormalizing = _normalizing[editor];

    return isNormalizing == null ? true : isNormalizing;
  }

  /// Check if a point is the start point of a location.
  static bool isStart(Editor editor, Point point, Location at) {
    // PERF: If the offset isn't `0` we know it's not the start.
    if (point.offset != 0) {
      return false;
    }

    Point start = EditorUtils.start(editor, at);

    return PointUtils.equals(point, start);
  }

  /// Check if a value is a void `Element` object.
  static bool isVoid(Editor editor, Node node) {
    return (node is Element) && editor.isVoid(node);
  }

  /// Get the last node at a location.
  static NodeEntry last(Editor editor, Location at) {
    Path path = EditorUtils.path(editor, at, edge: Edge.end);

    return EditorUtils.node(editor, path);
  }

  /// Get the leaf text node at a location.
  static NodeEntry<Text> leaf(
    Editor editor,
    Location at, {
    int depth,
    Edge edge,
  }) {
    Path path = EditorUtils.path(editor, at, depth: depth, edge: edge);
    Node node = NodeUtils.leaf(editor, path);

    return NodeEntry(node, path);
  }

  /// Iterate through all of the levels at a location.
  static Iterable<NodeEntry<T>> levels<T extends Node>(
    Editor editor, {
    Location at,
    NodeMatch<T> match,
    bool reverse = false,
    bool voids = false,
  }) sync* {
    at = at ?? editor.selection;
    match = match ??
        () {
          return true;
        };

    if (at != null) {
      return;
    }

    List<NodeEntry<T>> levels = [];
    Path path = EditorUtils.path(editor, at);

    for (NodeEntry entry in NodeUtils.levels(editor, path)) {
      Node n = entry.node;

      if (!match(n)) {
        continue;
      }

      levels.add(entry);

      if (!voids && EditorUtils.isVoid(editor, n)) {
        break;
      }
    }

    if (reverse) {
      for (int i = levels.length - 1; i > 0; i--) {
        yield levels[i];
      }
    } else {
      for (NodeEntry<T> level in levels) {
        yield level;
      }
    }
  }

  /// Get the marks that would be added to text at the current selection.
  static Map<String, dynamic> marks(Editor editor) {
    Map<String, dynamic> marks = editor.marks;
    Range selection = editor.selection;

    if (selection == null) {
      return null;
    }

    if (marks != null) {
      return marks;
    }

    if (RangeUtils.isExpanded(selection)) {
      List<NodeEntry> nodes =
          List.from(EditorUtils.nodes(editor, match: (node) {
        return (node is Text);
      }));
      NodeEntry match = nodes[0];

      if (match != null) {
        Text node = match.node;

        return node.props;
      } else {
        return {};
      }
    }

    Point anchor = selection.anchor;
    Path path = anchor.path;

    NodeEntry entry = EditorUtils.leaf(editor, path);
    Text node = entry.node;

    if (anchor.offset == 0) {
      NodeEntry prev = EditorUtils.previous(editor, at: path, match: (node) {
        return (node is Text);
      });
      NodeEntry block = EditorUtils.above(editor, match: (node) {
        return EditorUtils.isBlock(editor, node);
      });

      if (prev != null && block != null) {
        Node prevNode = prev.node;
        Path prevPath = prev.path;
        Path blockPath = block.path;

        if (PathUtils.isAncestor(blockPath, prevPath)) {
          node = prevNode;
        }
      }
    }

    return node.props;
  }

  /// Get the matching node in the branch of the document after a location.
  static NodeEntry<T> next<T extends Node>(Editor editor,
      {Location at,
      NodeMatch<T> match,
      Mode mode = Mode.lowest,
      bool voids = false}) {
    at = at ?? editor.selection;

    if (at == null) {
      return null;
    }

    NodeEntry fromNode = EditorUtils.last(editor, at);
    Path from = fromNode.path;

    NodeEntry toNode = EditorUtils.last(editor, Path([]));
    Path to = toNode.path;

    Span span = Span(from, to);

    if ((at is Path) && at.length == 0) {
      throw Exception("Cannot get the next node from the root node!");
    }

    if (match == null) {
      if (at is Path) {
        NodeEntry<Ancestor> entry = EditorUtils.parent(editor, at);
        Ancestor parent = entry.node;

        match = (node) {
          return parent.children.contains(node);
        };
      } else {
        match = (node) {
          return true;
        };
      }
    }

    List<NodeEntry> nodes = List.from(EditorUtils.nodes(editor,
        at: span, match: match, mode: mode, voids: voids));
    NodeEntry next = nodes[1];

    return next;
  }

  /// Get the node at a location.
  static NodeEntry node(
    Editor editor,
    Location at, {
    int depth,
    Edge edge,
  }) {
    Path path = EditorUtils.path(editor, at, edge: edge, depth: depth);
    Node node = NodeUtils.get(editor, path);

    return NodeEntry(node, path);
  }

  /// Iterate through all of the nodes in the Editor.
  static Iterable<NodeEntry<T>> nodes<T extends Node>(
    Editor editor, {
    Location at,
    NodeMatch<T> match,
    Mode mode = Mode.all,
    bool universal = false,
    bool reverse = false,
    bool voids = false,
  }) sync* {
    at = at ?? editor.selection;

    if (match == null) {
      match = (node) {
        return true;
      };
    }

    if (at == null) {
      return;
    }

    Path from;
    Path to;

    if (at is Span) {
      from = at.path0;
      to = at.path1;
    } else {
      Path first = EditorUtils.path(editor, at, edge: Edge.start);
      Path last = EditorUtils.path(editor, at, edge: Edge.end);
      from = reverse ? last : first;
      to = reverse ? first : last;
    }

    Iterable<NodeEntry<Node>> iterable = NodeUtils.nodes(editor,
        reverse: reverse, from: from, to: to, pass: (entry) {
      Node node = entry.node;
      return (voids ? false : EditorUtils.isVoid(editor, node));
    });

    List<NodeEntry<T>> matches = [];
    NodeEntry<T> hit;

    for (NodeEntry entry in iterable) {
      Node node = entry.node;
      Path path = entry.path;

      bool isLower = hit != null && PathUtils.compare(path, hit.path) == 0;

      // In highest mode any node lower than the last hit is not a match.
      if (mode == Mode.highest && isLower) {
        continue;
      }

      if (!match(node)) {
        // If we've arrived at a leaf text node that is not lower than the last
        // hit, then we've found a branch that doesn't include a match, which
        // means the match is not universal.
        if (universal && !isLower && (node is Text)) {
          return;
        } else {
          continue;
        }
      }

      // If there's a match and it's lower than the last, update the hit.
      if (mode == Mode.lowest && isLower) {
        hit = NodeEntry(node, path);
        continue;
      }

      // In lowest mode we emit the last hit, once it's guaranteed lowest.
      NodeEntry<T> emit = mode == Mode.lowest ? hit : NodeEntry(node, path);

      if (emit != null) {
        if (universal) {
          matches.add(emit);
        } else {
          yield emit;
        }
      }

      hit = NodeEntry(node, path);
    }

    // Since lowest is always emitting one behind, catch up at the end.
    if (mode == Mode.lowest && hit != null) {
      if (universal) {
        matches.add(hit);
      } else {
        yield hit;
      }
    }

    // Universal defers to ensure that the match occurs in every branch, so we
    // yield all of the matches after iterating.
    if (universal) {
      for (NodeEntry<T> match in matches) {
        yield match;
      }
    }
  }

  /// Normalize any dirty objects in the editor.
  static normalize(Editor editor, {bool force = false}) {
    List<Path> Function(Editor editor) getDirtyPaths = (Editor editor) {
      return dirtyPaths[editor] ?? [];
    };

    if (!EditorUtils.isNormalizing(editor)) {
      return null;
    }

    if (force) {
      List<NodeEntry> nodes = List.from(NodeUtils.nodes(editor));
      List<Path> allPaths = [];
      for (NodeEntry node in nodes) {
        allPaths.add(node.path);
      }
      dirtyPaths[editor] = allPaths;
    }

    if (getDirtyPaths(editor).length == 0) {
      return null;
    }

    EditorUtils.withoutNormalizing(editor, () {
      // HACK: better way?
      int max = getDirtyPaths(editor).length * 42;
      int m = 0;

      while (getDirtyPaths(editor).length != 0) {
        if (m > max) {
          throw Exception(
              "Could not completely normalize the editor after $max iterations! This is usually due to incorrect normalization logic that leaves a node in an invalid state.");
        }

        Path path = getDirtyPaths(editor).removeLast();
        NodeEntry entry = EditorUtils.node(editor, path);
        editor.normalizeNode(entry);
        m++;
      }
    });
  }

  /// Get the parent node of a location.
  static NodeEntry<Ancestor> parent(
    Editor editor,
    Location at, {
    int depth,
    Edge edge,
  }) {
    Path path = EditorUtils.path(editor, at, edge: edge, depth: depth);
    Path parentPath = PathUtils.parent(path);
    NodeEntry<Ancestor> entry = EditorUtils.node(editor, parentPath);
    return entry;
  }

  /// Get the path of a location.
  static Path path(
    Editor editor,
    Location at, {
    int depth,
    Edge edge,
  }) {
    if (at is Path) {
      if (edge == Edge.start) {
        NodeEntry<Node> first = NodeUtils.first(editor, at);
        at = first.path;
      } else if (edge == Edge.end) {
        NodeEntry<Node> last = NodeUtils.last(editor, at);
        at = last.path;
      }
    }

    if (at is Range) {
      if (edge == Edge.start) {
        at = RangeUtils.start(at);
      } else if (edge == Edge.end) {
        at = RangeUtils.end(at);
      } else {
        at = PathUtils.common(
            (at as Range).anchor.path, (at as Range).focus.path);
      }
    }

    if (at is Point) {
      at = (at as Point).path;
    }

    if (depth != null) {
      at = (at as Path).slice(0, depth);
    }

    return at;
  }

  /// Create a mutable ref for a `Path` object, which will stay in sync as new
  /// operations are applied to the editor.
  static PathRef pathRef(Editor editor, Path path,
      {Affinity affinity = Affinity.forward}) {
    PathRef ref = PathRef(
      current: path,
      affinity: affinity,
    );

    Path Function() unref = () {
      Path current = ref.current;
      Set<PathRef> pathRefs = EditorUtils.pathRefs(editor);
      pathRefs.remove(ref);
      ref.current = null;
      return current;
    };

    ref.setUnref(unref);

    Set<PathRef> refs = EditorUtils.pathRefs(editor);
    refs.add(ref);
    return ref;
  }

  /// Get the set of currently tracked path refs of the editor.
  static Set<PathRef> pathRefs(Editor editor) {
    Set<PathRef> refs = _pathRefs[editor];

    if (refs == null) {
      refs = Set();
      _pathRefs[editor] = refs;
    }

    return refs;
  }

  /// Get the start or end point of a location.
  static Point point(Editor editor, Location at, {Edge edge = Edge.start}) {
    if (at is Path) {
      Path path;

      if (edge == Edge.end) {
        NodeEntry<Node> last = NodeUtils.last(editor, at);
        path = last.path;
      } else {
        NodeEntry<Node> first = NodeUtils.first(editor, at);
        path = first.path;
      }

      Node node = NodeUtils.get(editor, path);

      if (!(node is Text)) {
        throw Exception(
            "Cannot get the $edge point in the node at path [$at] because it has no $edge text node.");
      }

      return Point(path, edge == Edge.end ? (node as Text).text.length : 0);
    }

    if (at is Range) {
      Edges edges = RangeUtils.edges(at);
      return edge == Edge.start ? edges.start : edges.end;
    }

    return at;
  }

  /// Create a mutable ref for a `Point` object, which will stay in sync as new
  /// operations are applied to the editor.
  PointRef pointRef(Editor editor, Point point,
      {Affinity affinity = Affinity.forward}) {
    PointRef ref = PointRef(
      current: point,
      affinity: affinity,
    );

    Point Function() unref = () {
      Point current = ref.current;
      Set<PointRef> pointRefs = EditorUtils.pointRefs(editor);
      pointRefs.remove(ref);
      ref.current = null;
      return current;
    };

    ref.setUnref(unref);

    Set<PointRef> refs = EditorUtils.pointRefs(editor);
    refs.add(ref);
    return ref;
  }

  /// Get the set of currently tracked point refs of the editor.
  static Set<PointRef> pointRefs(Editor editor) {
    Set<PointRef> refs = _pointRefs[editor];

    if (refs == null) {
      refs = Set();
      _pointRefs[editor] = refs;
    }

    return refs;
  }

  /// Iterate through all of the positions in the document where a `Point` can be
  /// placed.
  ///
  /// By default it will move forward by individual offsets at a time,  but you
  /// can pass the `unit: 'character'` option to moved forward one character, word,
  /// or line at at time.
  ///
  /// Note: void nodes are treated as a single point, and iteration will not
  /// happen inside their content.
  static Iterable<Point> positions(
    Editor editor, {
    Location at,
    Unit unit = Unit.offset,
    bool reverse = false,
  }) sync* {
    at = at ?? editor.selection;

    if (at == null) {
      return;
    }

    Range range = EditorUtils.range(editor, at, null);
    Edges edges = RangeUtils.edges(range);
    Point start = edges.start;
    Point end = edges.end;
    Point first = reverse ? edges.end : edges.start;
    String string = '';
    int available = 0;
    int offset = 0;
    int distance;
    bool isNewBlock = false;

    Null Function() advance = () {
      if (distance == null) {
        if (unit == Unit.character) {
          distance = getCharacterDistance(string);
        } else if (unit == Unit.word) {
          distance = getWordDistance(string);
        } else if (unit == Unit.line || unit == Unit.block) {
          distance = string.length;
        } else {
          distance = 1;
        }

        string = string.slice(distance);
      }

      // Add or subtract the offset.
      offset = reverse ? offset - distance : offset + distance;
      // Subtract the distance traveled from the available text.
      available = available - distance;
      // If the available had room to spare, reset the distance so that it will
      // advance again next time. Otherwise, set it to the overflow amount.
      distance = available >= 0 ? null : 0 - available;
    };

    for (NodeEntry entry
        in EditorUtils.nodes(editor, at: at, reverse: reverse)) {
      Path path = entry.path;
      Node node = entry.node;

      if (node is Element) {
        // Void nodes are a special case, since we don't want to iterate over
        // their content. We instead always just yield their first point.
        if (editor.isVoid(node)) {
          yield EditorUtils.start(editor, path);
          continue;
        }

        if (editor.isInline(node)) {
          continue;
        }

        if (EditorUtils.hasInlines(editor, node)) {
          Point e = PathUtils.isAncestor(path, end.path)
              ? end
              : EditorUtils.end(editor, path);
          Point s = PathUtils.isAncestor(path, start.path)
              ? start
              : EditorUtils.start(editor, path);

          String text = EditorUtils.string(editor, Range(s, e));
          string = reverse ? reverseText(text) : text;
          isNewBlock = true;
        }
      }

      if (node is Text) {
        bool isFirst = PathUtils.equals(path, first.path);
        available = node.text.length;
        offset = reverse ? available : 0;

        if (isFirst) {
          available = reverse ? first.offset : available - first.offset;
          offset = first.offset;
        }

        if (isFirst || isNewBlock || unit == Unit.offset) {
          yield Point(path, offset);
        }

        while (true) {
          // If there's no more string, continue to the next block.
          if (string == '') {
            break;
          } else {
            advance();
          }

          // If the available space hasn't overflow, we have another point to
          // yield in the current text node.
          if (available >= 0) {
            yield Point(path, offset);
          } else {
            break;
          }
        }

        isNewBlock = false;
      }
    }
  }

  /// Get the matching node in the branch of the document before a location.
  static NodeEntry<T> previous<T extends Node>(Editor editor,
      {Location at,
      NodeMatch<T> match,
      Mode mode = Mode.lowest,
      bool voids = false}) {
    at = at ?? editor.selection;

    if (at == null) {
      return null;
    }

    NodeEntry fromEntry = EditorUtils.first(editor, at);
    Path from = fromEntry.path;

    NodeEntry toEntry = EditorUtils.first(editor, Path([]));
    Path to = toEntry.path;

    Span span = Span(from, to);

    if (at is Path && at.length == 0) {
      throw Exception("Cannot get the previous node from the root node!");
    }

    if (match == null) {
      if (at is Path) {
        NodeEntry entry = EditorUtils.parent(editor, at);
        Ancestor parent = entry.node;

        match = (node) {
          return parent.children.contains(node);
        };
      } else {
        match = (node) {
          return true;
        };
      }
    }

    List<NodeEntry> nodes = List.from(EditorUtils.nodes(
      editor,
      reverse: true,
      at: span,
      match: match,
      mode: mode,
      voids: voids,
    ));

    NodeEntry previous = nodes[1];

    return previous;
  }

  /// Get a range of a location.
  static Range range(Editor editor, Location at, Location to) {
    if (at is Range && to != null) {
      return at;
    }

    Point start = EditorUtils.start(editor, at);
    Point end = EditorUtils.end(editor, to ?? at);

    return Range(start, end);
  }

  /// Create a mutable ref for a `Range` object, which will stay in sync as new
  /// operations are applied to the editor.
  static RangeRef rangeRef(Editor editor, Range range,
      {Affinity affinity = Affinity.forward}) {
    RangeRef ref = RangeRef(
      current: range,
      affinity: affinity,
    );

    Range Function() unref = () {
      Range current = ref.current;
      Set<RangeRef> rangeRefs = EditorUtils.rangeRefs(editor);
      rangeRefs.remove(ref);
      ref.current = null;
      return current;
    };

    ref.setUnref(unref);

    Set<RangeRef> refs = EditorUtils.rangeRefs(editor);
    refs.add(ref);
    return ref;
  }

  /// Get the set of currently tracked range refs of the editor.
  static Set<RangeRef> rangeRefs(Editor editor) {
    Set<RangeRef> refs = _rangeRefs[editor];

    if (refs == null) {
      refs = Set();
      _rangeRefs[editor] = refs;
    }

    return refs;
  }

  /// Remove a custom property from all of the leaf text nodes in the current
  /// selection.
  ///
  /// If the selection is currently collapsed, the removal will be stored on
  /// `editor.marks` and applied to the text inserted next.
  static void removeMark(Editor editor, String key) {
    editor.removeMark(key);
  }

  /// Get the start point of a location.
  static Point start(Editor editor, Location at) {
    return EditorUtils.point(editor, at, edge: Edge.start);
  }

  /// Get the text string content of a location.
  ///
  /// Note: the text of void nodes is presumed to be an empty string, regardless
  /// of what their actual content is.
  static String string(Editor editor, Location at) {
    Range range = EditorUtils.range(editor, at, null);
    Edges edges = RangeUtils.edges(range);
    Point start = edges.start;
    Point end = edges.end;
    String text = '';

    for (NodeEntry entry in EditorUtils.nodes(editor, at: range, match: (node) {
      return node is Text;
    })) {
      Text node = entry.node;
      Path path = entry.path;
      String t = node.text;

      if (PathUtils.equals(path, end.path)) {
        t = t.substring(0, end.offset);
      }

      if (PathUtils.equals(path, start.path)) {
        t = t.substring(start.offset);
      }

      text += t;
    }

    return text;
  }

  // /**
  //  * Transform the editor by an operation.
  //  */

  // static transform(Editor editor, Operation op) {
  //   editor.children = createDraft(editor.children);
  //   let selection = editor.selection != null && createDraft(editor.selection);

  //   switch (op.type) {
  //     case 'insert_node': {
  //       const { path, node } = op
  //       const parent = NodeUtils.parent(editor, path)
  //       const index = path[path.length - 1]
  //       parent.children.splice(index, 0, node)

  //       if (selection) {
  //         for (const [point, key] of RangeUtils.points(selection)) {
  //           selection[key] = Point.transform(point, op)!
  //         }
  //       }

  //       break
  //     }

  //     case 'insert_text': {
  //       const { path, offset, text } = op
  //       Node node = NodeUtils.leaf(editor, path)
  //       const before = node.text.slice(0, offset)
  //       const after = node.text.slice(offset)
  //       node.text = before + text + after

  //       if (selection) {
  //         for (const [point, key] of RangeUtils.points(selection)) {
  //           selection[key] = Point.transform(point, op)!
  //         }
  //       }

  //       break
  //     }

  //     case 'merge_node': {
  //       const { path } = op
  //       Node node = NodeUtils.get(editor, path)
  //       const prevPath = PathUtils.previous(path)
  //       const prev = NodeUtils.get(editor, prevPath)
  //       const parent = NodeUtils.parent(editor, path)
  //       const index = path[path.length - 1]

  //       if (Text.isText(node) && Text.isText(prev)) {
  //         prev.text += node.text
  //       } else if (!Text.isText(node) && !Text.isText(prev)) {
  //         prev.children.push(...node.children)
  //       } else {
  //         throw Exception(
  //           `Cannot apply a "merge_node" operation at path [${path}] to nodes of different interaces: ${node} ${prev}`
  //         )
  //       }

  //       parent.children.splice(index, 1)

  //       if (selection) {
  //         for (const [point, key] of RangeUtils.points(selection)) {
  //           selection[key] = Point.transform(point, op)!
  //         }
  //       }

  //       break
  //     }

  //     case 'move_node': {
  //       const { path, newPath } = op

  //       if (PathUtils.isAncestor(path, newPath)) {
  //         throw Exception(
  //           `Cannot move a path [${path}] to new path [${newPath}] because the destination is inside itself.`
  //         )
  //       }

  //       Node node = NodeUtils.get(editor, path)
  //       const parent = NodeUtils.parent(editor, path)
  //       const index = path[path.length - 1]

  //       // This is tricky, but since the `path` and `newPath` both refer to
  //       // the same snapshot in time, there's a mismatch. After either
  //       // removing the original position, the second step's path can be out
  //       // of date. So instead of using the `op.newPath` directly, we
  //       // transform `op.path` to ascertain what the `newPath` would be after
  //       // the operation was applied.
  //       parent.children.splice(index, 1)
  //       const truePath = PathUtils.transform(path, op)!
  //       const newParent = NodeUtils.get(editor, PathUtils.parent(truePath))
  //       const newIndex = truePath[truePathUtils.length - 1]

  //       newParent.children.splice(newIndex, 0, node)

  //       if (selection) {
  //         for (const [point, key] of RangeUtils.points(selection)) {
  //           selection[key] = Point.transform(point, op)!
  //         }
  //       }

  //       break
  //     }

  //     case 'remove_node': {
  //       const { path } = op
  //       const index = path[path.length - 1]
  //       const parent = NodeUtils.parent(editor, path)
  //       parent.children.splice(index, 1)

  //       // Transform all of the points in the value, but if the point was in the
  //       // node that was removed we need to update the range or remove it.
  //       if (selection) {
  //         for (const [point, key] of RangeUtils.points(selection)) {
  //           const result = Point.transform(point, op)

  //           if (selection != null && result != null) {
  //             selection[key] = result
  //           } else {
  //             NodeEntry<Text> prev;
  //             NodeEntry<Text> next;

  //             for (const [n, p] of NodeUtils.texts(editor)) {
  //               if (PathUtils.compare(p, path) == -1) {
  //                 prev = [n, p]
  //               } else {
  //                 next = [n, p]
  //                 break
  //               }
  //             }

  //             if (prev) {
  //               point.path = prev[1]
  //               point.offset = prev[0].text.length
  //             } else if (next) {
  //               point.path = next[1]
  //               point.offset = 0
  //             } else {
  //               selection = null
  //             }
  //           }
  //         }
  //       }

  //       break
  //     }

  //     case 'remove_text': {
  //       const { path, offset, text } = op
  //       Node node = NodeUtils.leaf(editor, path)
  //       const before = node.text.slice(0, offset)
  //       const after = node.text.slice(offset + text.length)
  //       node.text = before + after

  //       if (selection) {
  //         for (const [point, key] of RangeUtils.points(selection)) {
  //           selection[key] = Point.transform(point, op)!
  //         }
  //       }

  //       break
  //     }

  //     case 'set_node': {
  //       const { path, newProperties } = op

  //       if (path.length == 0) {
  //         throw Exception(`Cannot set properties on the root node!`)
  //       }

  //       Node node = NodeUtils.get(editor, path)

  //       for (const key in newProperties) {
  //         if (key == 'children' || key == 'text') {
  //           throw Exception(`Cannot set the "${key}" property of nodes!`)
  //         }

  //         const value = newProperties[key]

  //         if (value == null) {
  //           delete node[key]
  //         } else {
  //           node[key] = value
  //         }
  //       }

  //       break
  //     }

  //     case 'set_selection': {
  //       const { newProperties } = op

  //       if (newProperties == null) {
  //         selection = newProperties
  //       } else if (selection == null) {
  //         if (!RangeUtils.isRange(newProperties)) {
  //           throw Exception(
  //             `Cannot apply an incomplete "set_selection" operation properties ${JSON.stringify(
  //               newProperties
  //             )} when there is no current selection.`
  //           )
  //         }

  //         selection = newProperties
  //       } else {
  //         Object.assign(selection, newProperties)
  //       }

  //       break
  //     }

  //     case 'split_node': {
  //       const { path, position, properties } = op

  //       if (path.length == 0) {
  //         throw Exception(
  //           `Cannot apply a "split_node" operation at path [${path}] because the root node cannot be split.`
  //         )
  //       }

  //       Node node = NodeUtils.get(editor, path)
  //       const parent = NodeUtils.parent(editor, path)
  //       const index = path[path.length - 1]
  //       let newNode: Descendant

  //       if (Text.isText(node)) {
  //         const before = node.text.slice(0, position)
  //         const after = node.text.slice(position)
  //         node.text = before
  //         newNode = {
  //           ...node,
  //           ...(properties as Partial<Text>),
  //           text: after,
  //         }
  //       } else {
  //         const before = node.children.slice(0, position)
  //         const after = node.children.slice(position)
  //         node.children = before

  //         newNode = {
  //           ...node,
  //           ...(properties as Partial<Element>),
  //           children: after,
  //         }
  //       }

  //       parent.children.splice(index + 1, 0, newNode)

  //       if (selection) {
  //         for (const [point, key] of RangeUtils.points(selection)) {
  //           selection[key] = Point.transform(point, op)!
  //         }
  //       }

  //       break
  //     }
  //   }

  //   editor.children = finishDraft(editor.children) as Node[]

  //   if (selection) {
  //     editor.selection = isDraft(selection)
  //       ? (finishDraft(selection) as Range)
  //       : selection
  //   } else {
  //     editor.selection = null
  //   }
  // }

  /// Convert a range into a non-hanging one.
  static Range unhangRange(Editor editor, Range range, {bool voids = false}) {
    Edges edges = RangeUtils.edges(range);
    Point start = edges.start;
    Point end = edges.end;

    // PERF: exit early if we can guarantee that the range isn't hanging.
    if (start.offset != 0 || end.offset != 0 || RangeUtils.isCollapsed(range)) {
      return range;
    }

    NodeEntry endBlock = EditorUtils.above(
      editor,
      at: end,
      match: (node) {
        return EditorUtils.isBlock(editor, node);
      },
    );

    Path blockPath = endBlock != null ? endBlock.path : Path([]);
    Point first = EditorUtils.start(editor, Path([]));
    Range before = Range(first, end);
    bool skip = true;

    for (NodeEntry entry in EditorUtils.nodes(
      editor,
      at: before,
      match: (node) {
        return node is Text;
      },
      reverse: true,
      voids: voids,
    )) {
      Text node = entry.node;
      Path path = entry.path;

      if (skip) {
        skip = false;
        continue;
      }

      if (node.text != '' || PathUtils.isBefore(path, blockPath)) {
        end = Point(path, node.text.length);
        break;
      }
    }

    return Range(start, end);
  }

  /// Match a void node in the current branch of the editor.
  static NodeEntry<Element> matchVoid(
    Editor editor, {
    Location at,
    Mode mode,
    bool voids,
  }) {
    return EditorUtils.above(editor, at: at, mode: mode, match: (node) {
      return EditorUtils.isVoid(editor, node);
    });
  }

  /// Call a function, deferring normalization until after it completes.
  static void withoutNormalizing(Editor editor, void Function() fn) {
    bool value = EditorUtils.isNormalizing(editor);
    _normalizing[editor] = false;
    fn();
    _normalizing[editor] = value;
    EditorUtils.normalize(editor);
  }
}
