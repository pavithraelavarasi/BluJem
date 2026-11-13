import 'package:blujem/game/board.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_data.dart';

/// Plays [id] right by tapping its letters in order.
Board solve(Board b, int id) {
  final answer = b.row(id)!.answer;
  for (var k = 0; k < answer.length && !b.row(id)!.solved; k++) {
    b = b.form(id, b.row(id)!.letters.indexOf(answer[k], k));
  }
  return b;
}

String sorted(String s) => (s.replaceAll(' ', '').split('')..sort()).join();

void main() {
  test('the answer row keeps its letters, never doubling or dropping one, whatever order words come in', () {
    var b = solve(Board.start(samplePuzzle()), 1); // J A
    expect(sorted(b.finalRow.letters), 'AJ');

    b = b.form(finalRowId, b.finalRow.letters.indexOf('A')); // the player starts the answer
    expect(b.finalRow.letters.substring(0, 2), 'AJ');

    b = solve(b, 3); // word 3 before word 2: T A Y join
    expect(sorted(b.finalRow.letters), 'AAJTY');
    expect(b.finalRow.letters[0], 'A', reason: 'what the player formed stays put');
    expect(b.formedIn(finalRowId), 1);

    b = solve(b, 2); // W O L
    expect(sorted(b.finalRow.letters), sorted('JOLTAWAY'));
    expect(b.finalRow.letters.contains(' '), isFalse);
  });

  test('undo in the answer row survives a word solved in between', () {
    var b = solve(Board.start(samplePuzzle()), 1);
    final before = b.finalRow.letters;
    b = b.drag(finalRowId, 0, 1);
    b = solve(b, 3);
    b = b.undoLast();
    expect(b.finalRow.letters.substring(0, 2), before.substring(0, 2));
    expect(sorted(b.finalRow.letters), 'AAJTY');
  });

  test('the answer row can be finished once every word is in', () {
    var b = Board.start(samplePuzzle());
    for (final id in [3, 1, 2]) {
      b = solve(b, id);
    }
    expect(b.allWordsSolved, isTrue);
    b = solve(b, finalRowId);
    expect(b.finalRow.solved, isTrue);
    expect(b.finalRow.letters, 'JOLTAWAY');
  });
}
