import 'dart:convert';

import 'package:blujem/data/hint_service.dart';
import 'package:blujem/data/records_repository.dart';
import 'package:blujem/game/cartoon.dart';
import 'package:blujem/models/answer_shape.dart';
import 'package:blujem/models/box_rect.dart';
import 'package:blujem/models/puzzle.dart';
import 'package:blujem/models/records.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_data.dart';

void main() {
  group('answer shape', () {
    test("CREW'S SHIP is printed with its quotes and apostrophe", () {
      final shape = AnswerShape.of('"CREW\'S" SHIP');
      expect(shape.groups, [4, 1, 4]);
      expect(shape.marks, const [
        AnswerMark(0, '“', before: true),
        AnswerMark(3, '’', before: false),
        AnswerMark(4, '”', before: false),
      ]);
    });

    test('without quotes only the apostrophe is printed', () {
      final shape = AnswerShape.of("CREW'S SHIP");
      expect(shape.groups, [4, 1, 4]);
      expect(shape.marks, const [AnswerMark(3, '’', before: false)]);
      expect(AnswerShape.of('CREW’S SHIP').groups, [4, 1, 4]);
    });

    test('plain words are plain groups', () {
      final shape = AnswerShape.of('RANGE OF TOPICS');
      expect(shape.groups, [5, 2, 6]);
      expect(shape.marks, isEmpty);
    });

    test('a hyphen splits and a closing mark stays with its word', () {
      final shape = AnswerShape.of('HAND-ME-DOWNS!');
      expect(shape.groups, [4, 2, 5]);
      expect(shape.marks.last.text, '!');
      expect(shape.marks.last.index, 10);
    });

    test('the game row follows the typed shape only when it fits', () {
      expect(AnswerShape.groupsFor('"CREW\'S" SHIP', 9), [4, 1, 4]);
      expect(AnswerShape.groupsFor('"CREW\'S" SHIP', 8), [8]);
      expect(lettersOf('"CREW\'S" SHIP'), 'CREWSSHIP');
    });
  });

  group('puzzle wire format', () {
    test("reads the server's row, whose lists arrive as JSON text", () {
      final row = {
        'id': 'p1',
        'publishDate': '2026-10-23',
        'sheetDate': '',
        'timeLimitSeconds': 240,
        'aspectRatio': 0.8,
        'words': jsonEncode([
          {
            'scrambled': 'raja',
            'answer': 'ajar',
            'boxes': [
              for (final b in boxes(4, circled: {1})) b.toJson(),
            ],
          },
        ]),
        'finalAnswer': '"crew\'s" ship',
        'finalBoxes': jsonEncode([for (final b in boxes(9).reversed) b.toJson()]),
        'sheetKey': 'sheets/p1.png',
      };
      final p = Puzzle.fromJson(row);
      expect(p.sheetDate, '2026-10-23', reason: 'a blank sheet date falls back to the publish date');
      expect(p.words.single.answer, 'AJAR');
      expect(p.words.single.circles, [false, true, false, false]);
      expect(p.finalAnswerLetters, 'CREWSSHIP');
      expect(p.finalGroups, [4, 1, 4]);
      expect(p.finalBoxes.first.x, lessThan(p.finalBoxes.last.x), reason: 'sorted left to right');
      expect(p.isPlayable, isTrue);
    });

    test('a sheet whose answer does not fit its squares is not offered', () {
      final p = samplePuzzle(finalAnswer: 'SHORT');
      expect(p.isPlayable, isFalse);
    });

    test('survives a round trip through the cache', () {
      final p = samplePuzzle();
      final again = Puzzle.fromJson(p.toJson());
      expect(again.toJson(), p.toJson());
    });
  });

  group('stats', () {
    final now = DateTime(2026, 10, 28, 9);
    Completion run(DateTime at, {int seconds = 100, int hints = 0, bool timed = true}) => Completion(
      puzzleId: '${at.millisecondsSinceEpoch}',
      sheetDate: '',
      finalAnswer: '',
      seconds: seconds,
      hintsUsed: hints,
      completedAt: at.millisecondsSinceEpoch,
      timed: timed,
    );

    test('a streak ending yesterday is still alive; one ending before is not', () {
      final alive = RecordsRepository.statsFor([run(DateTime(2026, 10, 27, 23)), run(DateTime(2026, 10, 26, 8))], now);
      expect(alive.currentStreak, 2);
      expect(alive.solvedToday, isFalse);

      final lost = RecordsRepository.statsFor([run(DateTime(2026, 10, 25))], now);
      expect(lost.currentStreak, 0);
      expect(lost.longestStreak, 1);
    });

    test('two runs on one day count once; untimed runs have no time', () {
      final s = RecordsRepository.statsFor([
        run(DateTime(2026, 10, 28, 8), seconds: 90, hints: 1),
        run(DateTime(2026, 10, 28, 7), seconds: 50, timed: false),
        run(DateTime(2026, 10, 27, 7), seconds: 130),
      ], now);
      expect(s.currentStreak, 2);
      expect(s.solvedToday, isTrue);
      expect(s.bestSeconds, 90);
      expect(s.averageSeconds, 110);
      expect(s.hintsUsed, 1);
    });

    test('the better run is kept: timed, then fewer hints, then faster', () {
      final fast = run(now, seconds: 60, hints: 1);
      final clean = run(now, seconds: 200, hints: 0);
      expect(clean.isBetterThan(fast), isTrue);
      expect(run(now, timed: false, hints: 0).isBetterThan(fast), isFalse);
    });

    test('the speed multiplier matches the server table', () {
      expect([0, 60, 61, 90, 120, 180, 181].map(Multipliers.at), [5, 5, 4, 4, 3, 2, 1]);
      expect(Multipliers.secondsLeftAt(50), 10);
      expect(Multipliers.secondsLeftAt(200), isNull);
    });
  });

  group('hints', () {
    final glossary = {'AJAR': 'slightly open', 'AWAY': 'at a distance'};
    final puzzle = samplePuzzle();

    test('the word ladder goes from meaning to shape to spelling', () {
      final ladder = HintService.wordLadder(puzzle.words.first, glossary);
      expect(ladder, ['It means: slightly open.', 'It starts with A and ends with R, with 2 vowels.', 'A _ A _']);
    });

    test('the final ladder explains the last word, which carries the joke', () {
      final ladder = HintService.finalLadder(puzzle, glossary);
      expect(ladder.first, startsWith('The answer is 2 words (4 + 4 letters)'));
      expect(ladder[1], 'The last word means: at a distance.');
      expect(ladder[2], 'J _ _ _   A _ _ _');
    });

    test('a hint that spells the answer is refused', () {
      expect(HintService.leaks('Think of a door left a-jar', 'AJAR'), isTrue);
      expect(HintService.leaks('Slightly open', 'AJAR'), isFalse);
    });

    test('the glossary is one word and meaning per line', () {
      expect(parseGlossary('AJAR\tslightly open\nBAD LINE\nAWAY\tgone\r'), {'AJAR': 'slightly open', 'AWAY': 'gone'});
    });
  });

  group('cartoon', () {
    test('a frame is found from its long dark top and bottom edges', () {
      const w = 100, h = 100;
      final gray = List.filled(w * h, 255);
      for (var x = 55; x < 95; x++) {
        gray[10 * w + x] = 0;
        gray[80 * w + x] = 0;
      }
      final frame = findCartoonFrame(gray, w, h)!;
      expect(frame.x, closeTo(0.55, 0.01));
      expect(frame.y, closeTo(0.10, 0.01));
      expect(frame.bottom, closeTo(0.81, 0.01));
    });

    test('no frame: the right half above the answer row', () {
      expect(findCartoonFrame(List.filled(100 * 100, 255), 100, 100), isNull);
      final limit = cartoonSearchLimit([const BoxRect(0.1, 0.9, 0.05, 0.05)]);
      expect(cartoonPanel(null, limit), BoxRect(0.5, 0, 0.5, limit));
    });
  });
}
