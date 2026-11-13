import 'dart:math';

import 'package:blujem/game/board.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_data.dart';

void main() {
  Board start() => Board.start(samplePuzzle());
  String word(Board b, [int id = 1]) => b.row(id)!.letters;

  group('starting letters', () {
    test('the printed scramble is kept when it rearranges the answer', () {
      expect(startingLetters('RAJA', 'AJAR'), 'RAJA');
    });
    test('a misread scramble falls back to the answer, rotated', () {
      expect(startingLetters('XYZQ', 'AJAR'), 'JARA');
    });
    test('a scramble that already spells the answer is moved on', () {
      expect(startingLetters('AJAR', 'AJAR'), isNot('AJAR'));
    });
  });

  group('moving letters', () {
    test('a move slides the letters between, never swaps', () {
      expect(['G', 'T', 'A', 'N', 'R'].moved(4, 1).join(), 'GRTAN');
      expect(['A', 'B', 'C', 'D', 'E'].moved(2, 0).join(), 'CABDE');
    });

    test('a row is solved the moment it spells the answer, and locked', () {
      final b = start().move(1, 0, 3); // RAJA → AJAR
      expect(word(b), 'AJAR');
      expect(b.row(1)!.solved, isTrue);
      expect(identical(b.move(1, 0, 1), b), isTrue);
    });
  });

  group('tapping and dragging share one word', () {
    test('taps then a drag: the drag works on the formed word, and taps carry on from it', () {
      var b = start().form(1, 1); // RAJA → tap the first A: ARJA, one formed
      expect(word(b), 'ARJA');
      b = b.drag(1, 2, 1); // drag J into the second square: AJRA
      expect(word(b), 'AJRA');
      expect(b.formedIn(1), 1, reason: 'the formed A before the drop stays formed');
      b = b.form(1, 1).form(1, 3); // tap J (already next), then the last A: AJAR
      expect(word(b), 'AJAR');
      expect(b.row(1)!.solved, isTrue);
    });

    test('a drag then taps: tapping starts from the dragged word, not the original', () {
      var b = start().drag(1, 2, 0); // RAJA → JRAA
      expect(word(b), 'JRAA');
      b = b.form(1, 2).form(1, 3).form(1, 2); // an A (AJRA), the other A (AAJR), then J
      expect(word(b), 'AAJR');
      expect(b.formedIn(1), 4, reason: 'with one letter left, it can only go in the last square');
    });

    test('the two As are separate tiles: one tapped stays put while the other moves', () {
      var b = start().form(1, 1); // the first A formed
      final first = b.row(1)!.order[0];
      b = b.form(1, 3); // the second A
      expect(b.row(1)!.order[0], first, reason: 'the formed A is not taken again');
      expect(b.row(1)!.order[1], isNot(first));
    });
  });

  group('forming (tap the letters in order)', () {
    test('RAJA is formed into AJAR by tapping A, J, A', () {
      var b = start();
      b = b.form(1, 3);
      expect(word(b), 'ARAJ');
      expect(b.formedIn(1), 1);
      b = b.form(1, 3);
      expect(word(b), 'AJRA');
      expect(b.formedIn(1), 2);
      b = b.form(1, 3);
      expect(word(b), 'AJAR');
      expect(b.row(1)!.solved, isTrue);
    });

    test('tapping the letter already next just forms it', () {
      final b = start().form(1, 0);
      expect(word(b), 'RAJA');
      expect(b.formedIn(1), 1);
    });

    test('tapping a formed letter takes the word back to that point', () {
      var b = start().form(1, 1).form(1, 2);
      expect(b.formedIn(1), 2);
      b = b.form(1, 1);
      expect(b.formedIn(1), 1);
      expect(word(b), 'AJRA');
    });

    test('undo takes back the letter and the formed count', () {
      final b = start().form(1, 1).form(1, 2).undoLast();
      expect(word(b), 'ARJA');
      expect(b.formedIn(1), 1);
    });

    test('a drag behind the formed letters keeps them formed', () {
      final b = start().form(1, 1).drag(1, 2, 3);
      expect(word(b), 'ARAJ');
      expect(b.formedIn(1), 1);
    });

    test('a drag into the formed letters unforms from there', () {
      final b = start().form(1, 1).form(1, 2).drag(1, 3, 0);
      expect(word(b), 'AAJR');
      expect(b.formedIn(1), 0);
    });

    test('every word can be formed letter by letter', () {
      var b = start();
      for (final w in b.words) {
        for (var k = 0; k < w.answer.length; k++) {
          final letters = b.row(w.id)!.letters;
          final i = letters.indexOf(w.answer[k], k);
          b = b.form(w.id, i);
          if (b.row(w.id)!.solved) break;
          expect(b.row(w.id)!.letters.substring(0, k + 1), w.answer.substring(0, k + 1));
        }
        expect(b.row(w.id)!.solved, isTrue, reason: w.answer);
      }
    });
  });

  group('the answer row', () {
    test('starts blank and fills from each solved word\'s circles', () {
      var b = start();
      expect(b.follows, isTrue);
      expect(b.finalRow.letters, '        ');
      b = b.move(1, 0, 3); // AJAR solved: circles 1, 2 → J, A
      expect(b.finalRow.letters.substring(0, 2), 'JA');
      expect(b.finalRow.letters.substring(2).trim(), isEmpty);
    });

    test('forming in the answer row stops at the first empty square', () {
      var b = start().move(1, 0, 3);
      b = b.form(finalRowId, 1); // A to the front
      expect(b.finalRow.letters.substring(0, 2), 'AJ');
      expect(b.formedIn(finalRowId), 1);
      expect(identical(b.form(finalRowId, 5), b), isTrue, reason: 'blank square');
    });

    test('solving every word, then arranging the row, finishes it', () {
      var b = start().reveal(1).reveal(2).reveal(3);
      expect(b.finalRow.letters, 'JAWOLTAY');
      for (var k = 0; k < 8; k++) {
        final i = b.finalRow.letters.indexOf('JOLTAWAY'[k], k);
        b = b.form(finalRowId, i);
      }
      expect(b.finalRow.solved, isTrue);
    });

    test('a sheet whose circles do not add up still gets the answer letters', () {
      final b = Board.start(samplePuzzle(finalAnswer: 'NOT THE CIRCLES'));
      expect(b.follows, isFalse);
      expect((b.finalRow.letters.split('')..sort()).join(), ('NOTTHECIRCLES'.split('')..sort()).join());
    });

    test('revealing the answer before the words are done still shows it', () {
      final b = start().reveal(finalRowId);
      expect(b.finalRow.solved, isTrue);
      expect(b.finalRow.letters, 'JOLTAWAY');
    });
  });

  group('shuffle, shake and undo', () {
    test('a shuffle never lands on the same spelling', () {
      final b = start();
      for (var seed = 0; seed < 20; seed++) {
        expect(word(b.shuffle(1, Random(seed))), isNot('RAJA'));
      }
    });

    test('a shake jumbles every unsolved row and forgets what was formed', () {
      var b = start().move(1, 0, 3).form(2, 3);
      final before = b;
      b = b.rescramble(Random(3));
      expect(word(b, 1), 'AJAR', reason: 'solved rows stay');
      for (final id in [2, 3]) {
        expect((word(b, id).split('')..sort()).join(), (word(before, id).split('')..sort()).join());
        expect(b.formedIn(id), 0);
      }
      expect(word(b, 3), isNot(word(before, 3)));
    });

    String sorted(String w) => (w.split('')..sort()).join();

    test('a shake at the start jumbles every word, keeping its letters and circles', () {
      final before = start();
      final b = before.rescramble(Random(7));
      for (final id in [1, 2, 3]) {
        expect(word(b, id), isNot(word(before, id)), reason: 'word $id jumbled');
        expect(sorted(word(b, id)), sorted(word(before, id)), reason: 'same letters, duplicates too');
        expect(b.row(id)!.circles, before.row(id)!.circles, reason: 'circles stay on their squares');
      }
    });

    test('word 1 solved: a shake leaves it and jumbles the rest', () {
      final solved = start().move(1, 0, 3); // AJAR
      final b = solved.rescramble(Random(5));
      expect(word(b, 1), 'AJAR');
      expect(b.row(1)!.solved, isTrue);
      expect(word(b, 2), isNot(word(solved, 2)));
      expect(word(b, 3), isNot(word(solved, 3)));
    });

    test('words 1 and 3 solved: only word 2 jumbles', () {
      final solved = start().move(1, 0, 3).reveal(3); // AJAR, STAY
      final b = solved.rescramble(Random(9));
      expect(word(b, 1), 'AJAR');
      expect(word(b, 3), 'STAY');
      expect(word(b, 2), isNot(word(solved, 2)));
    });

    test('a shake never touches the answer row', () {
      var b = start().move(1, 0, 3); // AJAR drops J, A into the answer row
      b = b.move(finalRowId, 1, 0); // and the player has moved them there
      final answer = b.finalRow.letters;
      expect(b.rescramble(Random(11)).finalRow.letters, answer);
    });

    test('undo skips moves on a row solved since', () {
      var b = start().move(2, 0, 1).move(1, 0, 3); // word 2 moved, then word 1 solved
      expect(b.undo.where((s) => s.rowId == 1), isEmpty);
      b = b.undoLast();
      expect(word(b, 2), 'FLOW');
      expect(b.row(1)!.solved, isTrue);
    });

    test('reset puts a row back as it started', () {
      final b = start().move(2, 0, 3).reset(2);
      expect(word(b, 2), 'FLOW');
    });

    test('reveal solves a word with its own letters and locks it', () {
      final b = start().reveal(3);
      expect(word(b, 3), 'STAY');
      expect(b.row(3)!.revealed, isTrue);
      expect(spellingOrder('SISKDE', 'SKIDES'), isNotNull);
      expect(spellingOrder('ABC', 'ABD'), isNull);
    });
  });
}
