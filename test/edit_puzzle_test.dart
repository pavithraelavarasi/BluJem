import 'package:blujem/ui/screens/edit_puzzle_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_data.dart';

void main() {
  test('the edit form gives back the letters as typed: circled ones in capitals', () {
    final text = puzzleTextOf(samplePuzzle());
    expect(text.split('\n').take(3).toList(), ['rAJa', 'FLOw', 'tYSA']);
    expect(text, contains('\n\n'));
  });
}
