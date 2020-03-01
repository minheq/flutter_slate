import 'package:flutter_test/flutter_test.dart';
import 'package:inday/stela/interfaces/path.dart';
import 'package:inday/stela/interfaces/point.dart';
import 'package:inday/stela/interfaces/range.dart';

void main() {
  group("edges", () {
    test('backward', () {
      Point anchor = Point(Path([3]), 0);
      Point focus = Point(Path([0]), 0);
      Range range = Range(anchor, focus);

      List<Point> points = Range.edges(range);
      Point start = points[0];
      Point end = points[1];

      expect(Point.equals(focus, start), true);
      expect(Point.equals(anchor, end), true);
    });

    test('collapsed', () {
      Point anchor = Point(Path([0]), 0);
      Point focus = Point(Path([0]), 0);
      Range range = Range(anchor, focus);

      List<Point> points = Range.edges(range);
      Point start = points[0];
      Point end = points[1];

      expect(Point.equals(anchor, start), true);
      expect(Point.equals(focus, end), true);
    });

    test('forward', () {
      Point anchor = Point(Path([0]), 0);
      Point focus = Point(Path([3]), 0);
      Range range = Range(anchor, focus);

      List<Point> points = Range.edges(range);
      Point start = points[0];
      Point end = points[1];

      expect(Point.equals(anchor, start), true);
      expect(Point.equals(focus, end), true);
    });
  });

  group("equals", () {
    test('equal', () {
      Point anchor = Point(Path([0, 1]), 0);
      Point focus = Point(Path([0, 1]), 0);
      Range range = Range(anchor, focus);

      Point anotherAnchor = Point(Path([0, 1]), 0);
      Point anotherFocus = Point(Path([0, 1]), 0);
      Range another = Range(anotherAnchor, anotherFocus);

      expect(Range.equals(range, another), true);
    });

    test('not equal', () {
      Point anchor = Point(Path([0, 4]), 7);
      Point focus = Point(Path([0, 4]), 7);
      Range range = Range(anchor, focus);

      Point anotherAnchor = Point(Path([0, 1]), 0);
      Point anotherFocus = Point(Path([0, 1]), 0);
      Range another = Range(anotherAnchor, anotherFocus);

      expect(Range.equals(range, another), false);
    });
  });

  group("includes", () {
    test('path after', () {
      Point anchor = Point(Path([1]), 0);
      Point focus = Point(Path([3]), 0);
      Range range = Range(anchor, focus);

      Path path = Path([4]);

      expect(Range.includes(range, path), false);
    });

    test('path before', () {
      Point anchor = Point(Path([1]), 0);
      Point focus = Point(Path([3]), 0);
      Range range = Range(anchor, focus);

      Path target = Path([0]);

      expect(Range.includes(range, target), false);
    });

    test('path end', () {
      Point anchor = Point(Path([1]), 0);
      Point focus = Point(Path([3]), 0);
      Range range = Range(anchor, focus);

      Path target = Path([3]);

      expect(Range.includes(range, target), true);
    });

    test('path inside', () {
      Point anchor = Point(Path([1]), 0);
      Point focus = Point(Path([3]), 0);
      Range range = Range(anchor, focus);

      Path target = Path([2]);

      expect(Range.includes(range, target), true);
    });

    test('path inside', () {
      Point anchor = Point(Path([1]), 0);
      Point focus = Point(Path([3]), 0);
      Range range = Range(anchor, focus);

      Path target = Path([1]);

      expect(Range.includes(range, target), true);
    });

    test('point end', () {
      Point anchor = Point(Path([1]), 0);
      Point focus = Point(Path([3]), 0);
      Range range = Range(anchor, focus);

      Point target = Point(Path([3]), 0);

      expect(Range.includes(range, target), true);
    });

    test('point inside', () {
      Point anchor = Point(Path([1]), 0);
      Point focus = Point(Path([3]), 0);
      Range range = Range(anchor, focus);

      Point target = Point(Path([2]), 0);

      expect(Range.includes(range, target), true);
    });

    test('point offset after', () {
      Point anchor = Point(Path([1]), 0);
      Point focus = Point(Path([3]), 0);
      Range range = Range(anchor, focus);

      Point target = Point(Path([3]), 3);

      expect(Range.includes(range, target), false);
    });

    test('point offset after', () {
      Point anchor = Point(Path([1]), 3);
      Point focus = Point(Path([3]), 0);
      Range range = Range(anchor, focus);

      Point target = Point(Path([1]), 0);

      expect(Range.includes(range, target), false);
    });

    test('point path after', () {
      Point anchor = Point(Path([1]), 0);
      Point focus = Point(Path([3]), 0);
      Range range = Range(anchor, focus);

      Point target = Point(Path([4]), 0);

      expect(Range.includes(range, target), false);
    });

    test('point path before', () {
      Point anchor = Point(Path([1]), 0);
      Point focus = Point(Path([3]), 0);
      Range range = Range(anchor, focus);

      Point target = Point(Path([0]), 0);

      expect(Range.includes(range, target), false);
    });

    test('point start', () {
      Point anchor = Point(Path([1]), 0);
      Point focus = Point(Path([3]), 0);
      Range range = Range(anchor, focus);

      Point target = Point(Path([1]), 0);

      expect(Range.includes(range, target), true);
    });
  });

  group("isBackward", () {
    test('backward', () {
      Point anchor = Point(Path([3]), 0);
      Point focus = Point(Path([0]), 0);
      Range range = Range(anchor, focus);

      expect(Range.isBackward(range), true);
    });

    test('collapsed', () {
      Point anchor = Point(Path([0]), 0);
      Point focus = Point(Path([0]), 0);
      Range range = Range(anchor, focus);

      expect(Range.isBackward(range), false);
    });

    test('collapsed', () {
      Point anchor = Point(Path([0]), 0);
      Point focus = Point(Path([3]), 0);
      Range range = Range(anchor, focus);

      expect(Range.isBackward(range), false);
    });
  });

  group("isCollapsed", () {
    test('collapsed', () {
      Point anchor = Point(Path([0]), 0);
      Point focus = Point(Path([0]), 0);
      Range range = Range(anchor, focus);

      expect(Range.isCollapsed(range), true);
    });

    test('expanded', () {
      Point anchor = Point(Path([0]), 0);
      Point focus = Point(Path([3]), 0);
      Range range = Range(anchor, focus);

      expect(Range.isCollapsed(range), false);
    });
  });
}