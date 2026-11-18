import 'package:blujem/ui/widgets/sheet_views.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_data.dart';

/// The Start screen shows a few tiles of the cartoon; solving words opens more.
void main() {
  test('three open at the start, then more with each word, all at the end', () {
    expect(MysteryTiles.openFor(0, 4), 3);
    expect(MysteryTiles.openFor(1, 4), 5);
    expect(MysteryTiles.openFor(2, 4), 7);
    expect(MysteryTiles.openFor(3, 4), 9);
    expect(MysteryTiles.openFor(4, 4), MysteryTiles.count);
    expect(MysteryTiles.openFor(5, 6), 10);
    expect(MysteryTiles.openFor(6, 6), MysteryTiles.count);
  });

  test('never fewer open than before as words are solved', () {
    for (final total in [4, 6]) {
      for (var s = 1; s <= total; s++) {
        expect(MysteryTiles.openFor(s, total), greaterThanOrEqualTo(MysteryTiles.openFor(s - 1, total)));
      }
    }
  });

  test('the first tiles open in the middle rows, never over speech or caption', () {
    for (final puzzle in [samplePuzzle(), samplePuzzle(id: 'other-sheet')]) {
      final order = MysteryTiles.order(puzzle);
      expect(order.toSet().length, MysteryTiles.count);
      for (final i in order.take(MysteryTiles.atStart)) {
        expect(i, inInclusiveRange(MysteryTiles.columns, MysteryTiles.count - MysteryTiles.columns - 1));
      }
    }
  });
}
