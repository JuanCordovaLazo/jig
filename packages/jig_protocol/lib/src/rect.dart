/// Bounds of an element on screen, in logical pixels.
///
/// Reported for a caller to reason about a region - crop a screenshot, read a
/// layout, explain a failure. It is deliberately not a selector: no command
/// accepts a position as input, because a position a caller supplies is a guess
/// that expires silently when the app rebuilds.
final class JigRect {
  const JigRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  Map<String, Object?> toJson() => <String, Object?>{
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };

  static JigRect fromJson(Map<String, Object?> json) => JigRect(
        x: (json['x']! as num).toDouble(),
        y: (json['y']! as num).toDouble(),
        width: (json['width']! as num).toDouble(),
        height: (json['height']! as num).toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      other is JigRect &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(x, y, width, height);

  @override
  String toString() => 'JigRect($x, $y, ${width}x$height)';
}
