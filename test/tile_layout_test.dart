import 'package:blujem/ui/widgets/tile_row.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a short answer stays on one line at a comfortable size', () {
    final layout = TileLayout.of([5, 5], 400, maxSize: 44);
    expect(layout.positions.map((p) => p.dy).toSet(), {0});
    expect(layout.size, greaterThanOrEqualTo(TileLayout.minSize));
  });

  test('a long answer wraps between whole groups rather than shrinking', () {
    final layout = TileLayout.of([5, 7], 370, maxSize: 44); // PLANT MANAGER
    final lines = layout.positions.map((p) => p.dy).toList();
    expect(lines.toSet().length, 2);
    expect(lines.sublist(0, 5).toSet().length, 1, reason: 'PLANT together');
    expect(lines.sublist(5).toSet().length, 1, reason: 'MANAGER together');
    expect(layout.size, greaterThanOrEqualTo(TileLayout.minSize));
  });

  test('the nearest square is found from a point', () {
    final layout = TileLayout.of([4], 300, maxSize: 50);
    final third = layout.positions[2];
    expect(layout.nearest(third.translate(layout.size / 2, layout.size / 2)), 2);
  });
}
