import 'dart:io';
import 'dart:math';

import 'package:blujem/data/api_client.dart';
import 'package:blujem/data/hint_service.dart';
import 'package:blujem/data/local_store.dart';
import 'package:blujem/data/puzzle_library.dart';
import 'package:blujem/data/records_repository.dart';
import 'package:blujem/data/score_repository.dart';
import 'package:blujem/game/board.dart';
import 'package:blujem/game/game_controller.dart';
import 'package:blujem/ui/feedback.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_data.dart';

/// One word on its own: [letters] as shown (each tile its own pool index),
/// [answer] known, the cursor at [cursor].
Board word(String letters, String answer, {int cursor = 0}) {
  final row = RowState(id: 1, answer: answer, pool: letters, order: List.generate(letters.length, (i) => i));
  final board = Board(
    words: [row],
    finalRow: const RowState(id: finalRowId, answer: '', pool: '', order: []),
    follows: false,
  );
  return _withCursor(board, cursor);
}

/// Forms the first [n] letters as they stand, which puts the cursor at [n].
Board _withCursor(Board b, int n) {
  for (var i = 0; i < n; i++) {
    b = b.form(1, i);
  }
  return b;
}

void main() {
  group('the board', () {
    test('1. L D L O → D O L L, cursor on D: D goes to the first square, the L there comes to the cursor', () {
      final b = word('LDLO', 'DOLL', cursor: 1);
      expect(b.formedIn(1), 1);
      final hint = b.placeHint(1)!;
      final r = hint.board.row(1)!;
      expect(hint.square, 0, reason: "D's right square");
      expect(hint.tile, 1, reason: 'the D, by its own tile id');
      expect(r.letters, 'DLLO', reason: 'a swap: the other letters stay where they were');
      expect(r.fixed, {0});
      expect(r.solved, isFalse, reason: 'one hint, one letter');
      expect(hint.board.formedIn(1), 1, reason: 'the cursor stays: its new letter L is still wrong there');
      expect((r.order.toList()..sort()), [0, 1, 2, 3], reason: 'every tile once');
    });

    test('1b. the next hint sends the new cursor letter home in the same way', () {
      final b = word('LDLO', 'DOLL', cursor: 1).placeHint(1)!.board;
      final hint = b.placeHint(1)!;
      expect(hint.square, 3, reason: 'the L under the cursor goes to the last square, the only wrong L square');
      expect(hint.board.row(1)!.letters, 'DOLL');
      expect(hint.board.row(1)!.solved, isTrue);
    });

    test('2. duplicate letters: R A J A → A J A R, no tile lost or doubled', () {
      var b = word('RAJA', 'AJAR');
      final first = b.placeHint(1)!;
      expect(first.square, 3, reason: "R's home");
      expect(first.tile, 0);
      b = first.board;
      expect(b.row(1)!.letters, 'AAJR');
      expect(b.row(1)!.fixed, {3});
      expect(b.formedIn(1), 1, reason: 'the A now in square 0 is right, so the cursor moves to square 1');

      final second = b.placeHint(1)!;
      expect(second.square, 2, reason: 'the A goes to the A square that is wrong, not the one already right');
      b = second.board;
      expect(b.row(1)!.letters, 'AJAR');
      expect(b.row(1)!.solved, isTrue);
      expect((b.row(1)!.order.toList()..sort()), [0, 1, 2, 3]);
    });

    test('2b. an A with two wrong A squares goes to the nearer one', () {
      final hint = word('RAJA', 'AJAR', cursor: 1).placeHint(1)!;
      expect(hint.tile, 1);
      expect([0, 2], contains(hint.square));
      expect((hint.board.row(1)!.order.toList()..sort()), [0, 1, 2, 3]);
    });

    test('3. the cursor letter already right is skipped: the next wrong letter is helped', () {
      final b = word('DLLO', 'DOLL'); // the cursor's D is right
      final hint = b.placeHint(1)!;
      expect(hint.square, 3, reason: 'the L in square 1 goes to the last square');
      expect(hint.board.row(1)!.letters, 'DOLL');
    });

    test('a solved word gets no hint, and nothing changes', () {
      final b = word('LDLO', 'DOLL').placeHint(1)!.board.placeHint(1)!.board;
      expect(b.row(1)!.solved, isTrue);
      expect(b.placeHint(1), isNull);
    });

    test('a fixed letter cannot be tapped, dragged, mixed, reset or undone out of its square', () {
      var b = word('LDLO', 'DOLL', cursor: 1).drag(1, 2, 3); // a player move first
      b = b.placeHint(1)!.board;
      final fixedAt = b.row(1)!.fixed.single;
      final letter = b.row(1)!.letters[fixedAt];

      expect(b.form(1, fixedAt), same(b), reason: 'tap');
      expect(b.drag(1, fixedAt, 0), same(b), reason: 'drag from it');
      expect(b.drag(1, 0, fixedAt), same(b), reason: 'drag onto it');
      expect(b.canUndo, isFalse, reason: 'a hint is not undone, nor the moves before it');
      expect(b.reset(1).row(1)!.letters[fixedAt], letter);
      for (var seed = 0; seed < 30; seed++) {
        final mixed = b.shuffle(1, Random(seed)).row(1)!;
        expect(mixed.letters[fixedAt], letter, reason: 'Mix, seed $seed');
      }
    });

    test('other letters still move around a fixed one', () {
      final b = word('LDLO', 'DOLL', cursor: 1).placeHint(1)!.board; // D L L O, square 0 fixed
      final moved = b.drag(1, 3, 1);
      expect(moved.row(1)!.letters, 'DOLL', reason: 'O slides in past the Ls; the fixed D stays');
      expect(moved.row(1)!.solved, isTrue);
    });
  });

  group('in a game', () {
    late LocalStore store;
    late ApiClient api;
    final now = DateTime(2026, 10, 27, 10);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = await LocalStore.forTest(Directory.systemTemp.createTempSync('hint'));
      api = ApiClient(http: MockClient((req) async => http.Response('{}', 500)));
    });

    GameController game() {
      final library = PuzzleLibrary(api, store, clock: () => now)..debugSet(published: [samplePuzzle()]);
      return GameController(
        library: library,
        records: RecordsRepository(api, store, clock: () => now),
        scores: ScoreRepository(api, () => false),
        hints: HintService(api, () => false, loadGlossary: () async => ''),
        clock: () => now,
      )..openPuzzle(samplePuzzle());
    }

    test('4. a hint that completes a word runs the normal solved flow: circled letters reach the answer row', () async {
      final g = game()..start();
      final sounds = <GameSound>[];
      g.onSound = sounds.add;
      for (var i = 0; i < 2; i++) {
        await g.hintLetter(1);
        g.hinting = false; // the settle timer, without waiting for it
      }
      expect(g.board.row(1)!.solved, isTrue);
      expect(g.board.row(1)!.letters, 'AJAR');
      expect(g.board.finalRow.pool.replaceAll(' ', ''), 'JA', reason: 'the circled J and A, copied down');
      expect(g.board.solvedCount, 1);
      expect(g.hintsUsed, 2);
      expect(g.letterHints, {1: 2});
      expect(sounds.where((s) => s == GameSound.hint).length, 2);
      await Future<void>.delayed(GameController.hintMove + const Duration(milliseconds: 50));
      expect(sounds.last, GameSound.solved, reason: "the word's chime after the hint's");
      g.dispose();
    });

    test('5. a shake after a hint keeps the hinted letter and solved words, and mixes the rest', () async {
      final g = game()..start();
      await g.hintLetter(2); // F L O W → W . . .
      final fixedAt = g.board.row(2)!.fixed.single;
      final letter = g.board.row(2)!.letters[fixedAt];
      for (var i = 0; i < 10; i++) {
        g.rescramble();
        expect(g.board.row(2)!.letters[fixedAt], letter);
      }
      expect(g.hintsUsed, 1, reason: 'a shake is not a hint');
      g.dispose();
    });

    test('7. a quick double tap is one hint', () async {
      final g = game()..start();
      final sounds = <GameSound>[];
      g.onSound = sounds.add;
      final a = g.hintLetter(1);
      final b = g.hintLetter(1);
      await Future.wait([a, b]);
      await g.hintLetter(1); // still settling: ignored too
      expect(g.hintsUsed, 1);
      expect(g.board.row(1)!.fixed.length, 1);
      expect(sounds.where((s) => s == GameSound.hint).length, 1);
      g.dispose();
    });

    test('no hint before the puzzle starts, nor on a solved word, and none is counted', () async {
      final g = game();
      await g.hintLetter(1);
      expect(g.hintsUsed, 0);
      g.start();
      for (var i = 0; i < 2; i++) {
        await g.hintLetter(1);
        g.hinting = false;
      }
      await g.hintLetter(1); // solved now
      expect(g.hintsUsed, 2);
      g.dispose();
    });
  });

  test('6. with sound off, a hint still buzzes (once) and plays nothing', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.forTest(Directory.systemTemp.createTempSync('mute'));
    final buzzes = <Object?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') buzzes.add(call.arguments);
        return null;
      },
    );
    final feedback = GameFeedback(store)..toggleMuted();
    expect(feedback.muted, isTrue);
    feedback.play(GameSound.hint); // would throw without the audio plugin if it tried to play
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(buzzes, [
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.lightImpact',
    ], reason: 'one short-short buzz');
  });
}
