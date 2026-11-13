import 'dart:io';

import 'package:blujem/core/slots.dart';
import 'package:blujem/data/api_client.dart';
import 'package:blujem/data/local_store.dart';
import 'package:blujem/data/puzzle_library.dart';
import 'package:blujem/game/board.dart';
import 'package:blujem/models/answer_shape.dart';
import 'package:blujem/models/puzzle.dart';
import 'package:blujem/ui/widgets/tile_row.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _box({bool c = false}) => {'x': 0, 'y': 0, 'w': 0, 'h': 0, if (c) 'c': true};

/// Nov 6's puzzle as a player receives it: hashes, no answers.
Puzzle _hidden({String id = 'p1', String date = '2026-12-01', String slot = 'evening', int publishAt = 0}) {
  const answers = ['MUSTY', 'NIFTY', 'SWAYED', 'DECENT'];
  const scrambles = ['YMSTU', 'YFNTI', 'DSYWEA', 'ETCNDE'];
  const circled = [
    [0, 2, 3],
    [1, 2, 3],
    [2, 4, 5],
    [1, 3, 4, 5],
  ];
  return Puzzle.fromJson({
    'id': id,
    'publishDate': date,
    'slot': slot,
    'publishAt': publishAt,
    'image': '/tmp/$id-cartoon.png',
    'words': [
      for (var i = 0; i < 4; i++)
        {
          'scrambled': scrambles[i],
          'answerHash': answerHash(id, answers[i]),
          'boxes': [for (var j = 0; j < scrambles[i].length; j++) _box(c: circled[i].contains(j))],
        },
    ],
    'finalAnswer': '',
    'finalHash': answerHash(id, 'ADMITTENTSFEE', isFinal: true),
    'finalPattern': '"□□□□□-\n□□□□□" □□□',
    'finalBoxes': [for (var i = 0; i < 13; i++) _box(c: true)],
  });
}

/// Puts [word] in [row] by moving letters, as a player would.
Board _spell(Board board, int rowId, String word) {
  var b = board;
  for (var i = 0; i < word.length; i++) {
    final r = b.row(rowId)!;
    final at = [for (var j = i; j < r.length; j++) j].firstWhere((j) => r.letters[j] == word[i]);
    b = b.move(rowId, at, i);
  }
  return b;
}

void main() {
  group('answers checked by hash', () {
    test('the hash matches the server\'s, letters only', () {
      // jumble_data/test/puzzles.test.js prints the same for p1:MUSTY.
      expect(answerHash('p1', 'MUSTY'), '9c124bfc5ffe7d9ee71eec760e96e8be8a9a1df5b2e7ac71656ce8b2b52249a8');
      expect(answerHash('p1', 'musty'), answerHash('p1', 'MUSTY'));
    });

    test('a hidden puzzle is playable and solves word by word, then the answer', () {
      final puzzle = _hidden();
      expect(puzzle.answersHidden, isTrue);
      expect(puzzle.isPlayable, isTrue, reason: '${puzzle.problems}');
      var board = Board.start(puzzle);
      expect(board.words.first.letters, 'YMSTU');
      board = _spell(board, 1, 'MUSTY');
      expect(board.row(1)!.solved, isTrue);
      expect(board.row(2)!.solved, isFalse);
      // A wrong anagram is not taken for the answer.
      board = _spell(board, 2, 'FINTY');
      expect(board.row(2)!.solved, isFalse);
      board = _spell(board, 2, 'NIFTY');
      board = _spell(board, 3, 'SWAYED');
      board = _spell(board, 4, 'DECENT');
      expect(board.allWordsSolved, isTrue);
      board = _spell(board, finalRowId, 'ADMITTENTSFEE');
      expect(board.finalRow.solved, isTrue);
      expect(puzzle.finalFrom(board.finalRow.letters), '"ADMIT-TENTS" FEE');
    });

    test('answers from the server fill in without moving a letter', () {
      final puzzle = _hidden();
      final board = _spell(Board.start(puzzle), 1, 'MUSTY');
      final full = puzzle.withAnswers(['MUSTY', 'NIFTY', 'SWAYED', 'DECENT'], '"ADMIT-TENTS" FEE', 'A pun.');
      final filled = board.withAnswers(full);
      expect(full.answersHidden, isFalse);
      expect(filled.row(1)!.solved, isTrue);
      expect(filled.row(2)!.answer, 'NIFTY');
      expect(filled.row(2)!.letters, board.row(2)!.letters);
      expect(filled.reveal(2).row(2)!.letters, 'NIFTY');
    });
  });

  group('answer strip from the pattern', () {
    final puzzle = _hidden();

    test('boxes, groups and punctuation come from the pattern', () {
      expect(puzzle.finalLetterCount, 13);
      expect(puzzle.finalGroups, [5, 5, 3]);
      final shape = AnswerShape.of(puzzle.finalShapeText);
      expect(shape.marks, [
        const AnswerMark(0, '“', before: true),
        const AnswerMark(4, '-', before: false),
        const AnswerMark(9, '”', before: false),
      ]);
    });

    test('a new line in the pattern is where the strip wraps', () {
      expect(puzzle.finalLineBreaks, [1]);
      expect(TileLayout.splitAt([5, 5, 3], [1]), [
        [5],
        [5, 3],
      ]);
      // Too wide for one line: wrapped after the first word, as typed.
      final layout = TileLayout.of([5, 5, 3], 360, maxSize: 44, breaks: [1]);
      final lines = layout.positions.map((o) => o.dy).toSet();
      expect(lines.length, 2);
      expect(layout.positions.where((o) => o.dy == 0).length, 5);
      // Wide enough: one line, breaks or not.
      expect(TileLayout.of([5, 5, 3], 2000, maxSize: 44, breaks: [1]).positions.map((o) => o.dy).toSet(), {0});
    });

    test('a pattern with no line break leaves wrapping to the layout', () {
      final flat = Puzzle.fromJson({..._hidden().toJson(), 'finalPattern': '□□□ □□□□□-□□□□'});
      expect(flat.finalLineBreaks, isEmpty);
    });
  });

  group('the day\'s slots', () {
    // 2026-12-01 is a Tuesday. Times are India's: UTC+5:30.
    // The admin published the morning one at 9:12 AM; the afternoon one opens at 3 PM, the night one at 9 PM.
    final morning = _hidden(
      id: 'm',
      slot: 'morning',
      publishAt: DateTime.utc(2026, 12, 1, 3, 42).millisecondsSinceEpoch,
    );
    final evening = _hidden(
      id: 'e',
      slot: 'evening',
      publishAt: slotStart('2026-12-01', Slot.evening).millisecondsSinceEpoch,
    );

    Future<PuzzleLibrary> at(DateTime utc) async {
      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.forTest(Directory.systemTemp.createTempSync('slots'));
      return PuzzleLibrary(ApiClient(http: MockClient((_) async => http.Response('{}', 500))), store, clock: () => utc)
        ..debugSet(published: [morning, evening]);
    }

    test('before 3 PM only the morning puzzle is out, and the later slots say when', () async {
      final library = await at(DateTime.utc(2026, 12, 1, 9)); // 2:30 PM IST
      expect(library.todaysPuzzles.map((p) => p.id), ['m']);
      expect(library.dayPuzzle.id, 'm');
      expect(library.upcomingToday.map((u) => u.$1), [Slot.evening, Slot.night]);
      expect(library.all.map((p) => p.id), isNot(contains('e')));
      // The admin still sees it, scheduled.
      expect(library.published.map((p) => p.id), containsAll(['m', 'e']));
    });

    test('from 3 PM both are out, the afternoon one first, and the night one says when', () async {
      final library = await at(DateTime.utc(2026, 12, 1, 9, 30));
      expect(library.todaysPuzzles.map((p) => p.id), ['m', 'e']);
      expect(library.dayPuzzle.id, 'e');
      expect(library.upcomingToday.map((u) => u.$1), [Slot.night]);
      expect(library.all.take(2).map((p) => p.id), ['e', 'm']);
    });

    test('until the admin publishes the morning one, nothing of today is out', () async {
      final library = await at(DateTime.utc(2026, 12, 1, 3)); // 8:30 AM IST
      expect(library.todaysPuzzles, isEmpty);
      // The morning one has no time to count down to; only the later ones do.
      expect(library.upcomingToday.map((u) => u.$1), [Slot.evening, Slot.night]);
      // Nor is it polled for: its notification says when it is out.
      expect(library.missingOpenedSlot, isFalse);
    });

    test('a morning puzzle just published shows even on a phone a little behind', () async {
      final library = await at(DateTime.utc(2026, 12, 1, 3, 41)); // a minute before the server's 9:12
      expect(library.todaysPuzzles.map((p) => p.id), ['m']);
    });

    test('a slot that has opened without its puzzle is waited for', () async {
      final library = await at(DateTime.utc(2026, 12, 1, 9, 31));
      library.debugSet(published: [morning]);
      expect(library.missingOpenedSlot, isTrue);
    });

    test('a puzzle from before slots counts as its day\'s first', () {
      final old = Puzzle.fromJson({..._hidden().toJson(), 'slot': '', 'publishAt': 0, 'publishDate': '2026-11-08'});
      expect(old.slotKind, Slot.sunday);
      expect(old.releasedAt, DateTime.utc(2026, 11, 8, 0, 30)); // Sunday, 6:00 IST
    });
  });

  group('slot labels', () {
    test('the afternoon and night show their time; the morning and Sunday open when published', () {
      expect(Slot.evening.heading, 'Afternoon · 3:00 PM');
      expect(Slot.night.heading, 'Night · 9:00 PM');
      expect(Slot.morning.heading, 'Morning');
      expect(Slot.sunday.heading, 'Mega Jumble');
      expect([for (final s in Slot.values) s.opensOnPublish], [true, false, false, true]);
    });
  });
}
