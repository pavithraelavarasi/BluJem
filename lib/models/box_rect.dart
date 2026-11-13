/// One printed square on a puzzle sheet, as fractions (0..1) of the image's
/// width and height, so the same numbers work at any size the sheet is drawn.
class BoxRect {
  const BoxRect(this.x, this.y, this.w, this.h, {this.circled = false});

  final double x;
  final double y;
  final double w;
  final double h;

  /// Printed with a circle: its letter carries into the final answer.
  final bool circled;

  double get right => x + w;
  double get bottom => y + h;

  factory BoxRect.fromJson(Map<String, dynamic> j) => BoxRect(
    (j['x'] as num).toDouble(),
    (j['y'] as num).toDouble(),
    (j['w'] as num).toDouble(),
    (j['h'] as num).toDouble(),
    circled: j['c'] == true,
  );

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'w': w, 'h': h, if (circled) 'c': true};

  @override
  bool operator ==(Object other) =>
      other is BoxRect && other.x == x && other.y == y && other.w == w && other.h == h && other.circled == circled;

  @override
  int get hashCode => Object.hash(x, y, w, h, circled);

  @override
  String toString() => 'BoxRect($x, $y, $w, $h${circled ? ', circled' : ''})';
}
