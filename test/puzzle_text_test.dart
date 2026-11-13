import 'dart:convert';
import 'dart:io';

import 'package:blujem/admin/typed_puzzle.dart';
import 'package:blujem/core/slots.dart';
import 'package:flutter_test/flutter_test.dart';

/// The same cases the server's parser is tested with
/// (catalyst/functions/jumble_data/test/puzzles.test.js), so the app and the
/// server never read the admin's text differently.
void main() {
  final cases = jsonDecode(File('test/fixtures/puzzle_text_cases.json').readAsStringSync()) as Map<String, dynamic>;

  group('parser', () {
    for (final c in (cases['valid'] as List).cast<Map<String, dynamic>>()) {
      test('reads: ${c['name']}', () {
        final p = TypedPuzzle.parse(c['text'] as String, words: c['words'] as int);
        expect(p.scrambles, c['scrambles']);
        expect([
          for (final row in p.circles)
            [
              for (var i = 0; i < row.length; i++)
                if (row[i]) i,
            ],
        ], c['circled']);
        expect(p.pattern, c['pattern']);
        expect(p.squares, c['boxes']);
        expect(p.groups, c['groups']);
        expect(p.lines, c['lines']);
      });
    }

    for (final c in (cases['invalid'] as List).cast<Map<String, dynamic>>()) {
      test('refuses: ${c['name']}', () {
        expect(
          () => TypedPuzzle.parse(c['text'] as String, words: c['words'] as int),
          throwsA(isA<FormatException>().having((e) => e.message, 'message', contains(c['error'] as String))),
        );
      });
    }
  });

  group('slots (India time)', () {
    test('morning no earlier than 9:00, Sunday 6:00, the afternoon at 15:00, the night at 21:00', () {
      expect(slotStart('2026-12-01', Slot.morning), DateTime.utc(2026, 12, 1, 3, 30));
      expect(slotStart('2026-12-01', Slot.evening), DateTime.utc(2026, 12, 1, 9, 30));
      expect(slotStart('2026-12-01', Slot.night), DateTime.utc(2026, 12, 1, 15, 30));
      expect(slotStart('2026-12-06', Slot.sunday), DateTime.utc(2026, 12, 6, 0, 30));
      expect(Slot.forDate('2026-12-05'), [Slot.morning, Slot.evening, Slot.night]);
      expect(Slot.forDate('2026-12-06'), [Slot.sunday]);
      expect(Slot.sunday.words, 6);
      expect(Slot.evening.time, '3:00 PM');
      expect(Slot.night.time, '9:00 PM');
    });

    test('a slot that does not belong to its day is refused', () {
      expect(slotProblem('2026-12-06', Slot.morning), isNotNull);
      expect(slotProblem('2026-12-05', Slot.sunday), isNotNull);
      expect(slotProblem('2026-12-05', Slot.evening), isNull);
    });

    test("the puzzle day is India's, wherever the phone is", () {
      expect(indiaDate(DateTime.utc(2026, 12, 1, 18, 29)), '2026-12-01');
      expect(indiaDate(DateTime.utc(2026, 12, 1, 18, 30)), '2026-12-02');
    });
  });
}
