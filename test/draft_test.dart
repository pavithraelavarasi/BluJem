import 'dart:io';

import 'package:blujem/data/api_client.dart';
import 'package:blujem/data/hint_service.dart';
import 'package:blujem/data/local_store.dart';
import 'package:blujem/data/puzzle_library.dart';
import 'package:blujem/data/records_repository.dart';
import 'package:blujem/data/score_repository.dart';
import 'package:blujem/game/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var now = DateTime(2026, 10, 27, 10);
  late LocalStore store;
  late ApiClient api;
  final a = samplePuzzle(id: 'a');
  final b = samplePuzzle(id: 'b', publishDate: '2026-10-26');

  setUp(() async {
    now = DateTime(2026, 10, 27, 10);
    SharedPreferences.setMockInitialValues({});
    store = await LocalStore.forTest(Directory.systemTemp.createTempSync('draft'));
    api = ApiClient(http: MockClient((req) async => http.Response('{}', 500)));
  });

  GameController game() {
    final library = PuzzleLibrary(api, store, clock: () => now)..debugSet(published: [a, b]);
    return GameController(
      library: library,
      records: RecordsRepository(api, store, clock: () => now),
      scores: ScoreRepository(api, () => false),
      hints: HintService(api, () => false, loadGlossary: () async => ''),
      clock: () => now,
    );
  }

  /// Solves word 1 (RAJA → AJAR) by tapping.
  void solveFirst(GameController g) {
    for (final c in 'AJAR'.split('')) {
      final r = g.board.row(1)!;
      g.tapLetter(1, r.letters.indexOf(c, g.board.formedIn(1)));
    }
  }

  test('off the board the clock holds; back on it, it carries on', () {
    final g = game()
      ..openPuzzle(a)
      ..boardShown()
      ..start();
    now = now.add(const Duration(seconds: 40));
    g.tick();
    expect(g.remainingSeconds, 260);

    g.boardHidden(); // back to Today
    now = now.add(const Duration(minutes: 10));
    g.tick();
    expect(g.remainingSeconds, 260, reason: 'time away is not counted');

    g.boardShown();
    expect(g.paused, isFalse);
    now = now.add(const Duration(seconds: 5));
    g.tick();
    expect(g.remainingSeconds, 255);
    g.dispose();
  });

  test('another puzzle opened and back: the first is where it was, its clock paused meanwhile', () {
    final g = game()
      ..openPuzzle(a)
      ..boardShown()
      ..start();
    solveFirst(g);
    now = now.add(const Duration(seconds: 30));
    g.tick();
    final letters = [for (final w in g.board.words) w.letters];

    g.boardHidden();
    g.openPuzzle(b);
    expect(g.puzzle.id, 'b');
    expect(g.started, isFalse, reason: 'b starts fresh');
    expect(g.hasDraft('a'), isTrue);

    now = now.add(const Duration(minutes: 3));
    g.openPuzzle(a);
    g.boardShown();
    expect(g.puzzle.id, 'a');
    expect(g.started, isTrue);
    expect(g.board.row(1)!.solved, isTrue);
    expect([for (final w in g.board.words) w.letters], letters);
    expect(g.remainingSeconds, 270, reason: 'the 3 minutes away did not count');
    expect(g.showResumedNotice, isTrue);
    g.dispose();
  });

  test('both puzzles part-way keep their own drafts', () {
    final g = game()
      ..openPuzzle(a)
      ..start();
    solveFirst(g);
    g.openPuzzle(b);
    g.start();
    g.openPuzzle(a);
    expect(g.board.row(1)!.solved, isTrue);
    expect(g.hasDraft('b'), isTrue);
    g.openPuzzle(b);
    expect(g.started, isTrue);
    expect(g.board.row(1)!.solved, isFalse);
    g.dispose();
  });

  test('Reset puzzle starts clean, and a finished puzzle leaves no draft', () {
    final g = game()
      ..openPuzzle(a)
      ..start();
    solveFirst(g);
    g.resetPuzzle();
    expect(g.started, isFalse);
    expect(g.board.row(1)!.solved, isFalse);
    g.openPuzzle(b);
    expect(g.hasDraft('a'), isFalse, reason: 'nothing was begun after the reset');
    g.dispose();
  });

  test('another account, or the app fully closed, starts fresh', () async {
    final g = game()
      ..openPuzzle(a)
      ..start();
    solveFirst(g);
    g.openPuzzle(b);
    expect(g.hasDraft('a'), isTrue);
    await g.onAccountChanged('someone-else');
    expect(g.hasDraft('a'), isFalse);
    g.dispose();

    // A new controller is a new app start: drafts are not kept on the phone.
    final next = game()..openPuzzle(a);
    expect(next.started, isFalse);
    next.dispose();
  });
}
