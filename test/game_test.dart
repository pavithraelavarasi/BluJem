import 'dart:io';

import 'package:blujem/data/api_client.dart';
import 'package:blujem/data/hint_service.dart';
import 'package:blujem/data/local_store.dart';
import 'package:blujem/data/puzzle_library.dart';
import 'package:blujem/data/records_repository.dart';
import 'package:blujem/data/score_repository.dart';
import 'package:blujem/game/board.dart';
import 'package:blujem/game/game_controller.dart';
import 'package:blujem/models/puzzle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var now = DateTime(2026, 10, 28, 10);
  DateTime clock() => now;

  late LocalStore store;
  late ApiClient api;
  late List<String> calls;

  setUp(() async {
    now = DateTime(2026, 10, 28, 10);
    SharedPreferences.setMockInitialValues({});
    store = await LocalStore.forTest(Directory.systemTemp.createTempSync('blujem'));
    calls = [];
    api = ApiClient(
      http: MockClient((req) async {
        calls.add(req.url.path.split('/execute/').last);
        return http.Response('{}', 500);
      }),
    );
  });

  PuzzleLibrary libraryWith(List<Puzzle> published) => PuzzleLibrary(api, store, clock: clock)
    ..debugSet(
      published: published,
      bundled: [samplePuzzle(id: 'bundled', publishDate: '2026-07-18')],
    );

  GameController gameWith(PuzzleLibrary library, {bool signedIn = false}) => GameController(
    library: library,
    records: RecordsRepository(api, store, clock: clock),
    scores: ScoreRepository(api, () => signedIn),
    hints: HintService(api, () => false, loadGlossary: () async => 'AJAR\tslightly open'),
    clock: clock,
  );

  group("today's puzzle, or the latest before it", () {
    test("today's published sheet is the day's puzzle", () {
      final lib = libraryWith([
        samplePuzzle(id: 'today', publishDate: '2026-10-28'),
        samplePuzzle(id: 'y', publishDate: '2026-10-27'),
      ]);
      expect(lib.dayKind, DayKind.today);
      expect(lib.dayPuzzle.id, 'today');
    });

    test("without it, yesterday's stands in", () {
      final lib = libraryWith([samplePuzzle(id: 'y', publishDate: '2026-10-27')]);
      expect(lib.dayKind, DayKind.standIn);
      expect(lib.dayPuzzle.id, 'y');
      expect(lib.standInDayName(), "yesterday's");
    });

    test('an older stand-in is named by its date', () {
      final lib = libraryWith([samplePuzzle(id: 'o', publishDate: '2026-10-24')]);
      expect(lib.standInDayName(), "October 24's");
    });

    test('a future sheet never stands in, and bundled samples never count', () {
      final lib = libraryWith([samplePuzzle(id: 'f', publishDate: '2026-10-30')]);
      expect(lib.dayKind, DayKind.awaiting);
      expect(lib.dayPuzzle.id, 'bundled');
    });

    test('the awaiting sample cannot be started', () {
      final game = gameWith(libraryWith([]));
      expect(game.awaitingToday, isTrue);
      game.start();
      expect(game.started, isFalse);
    });
  });

  group('a run', () {
    test('nothing moves before Start', () {
      final game = gameWith(libraryWith([samplePuzzle(id: 'today', publishDate: '2026-10-28')]));
      game.tapLetter(1, 3);
      expect(game.board.row(1)!.letters, 'RAJA');
    });

    test('the clock holds while the player is away', () {
      final game = gameWith(libraryWith([samplePuzzle(id: 'today', publishDate: '2026-10-28')]));
      game.start();
      now = now.add(const Duration(seconds: 40));
      game.tick();
      expect(game.remainingSeconds, 260);
      game.onLeftApp();
      now = now.add(const Duration(minutes: 30));
      game.onResumed();
      expect(game.remainingSeconds, 260);
      expect(game.showResumedNotice, isTrue);
      game.dispose();
    });

    test('running out of time leaves practice mode, unscored by time', () {
      final game = gameWith(libraryWith([samplePuzzle(id: 'today', publishDate: '2026-10-28')]));
      game.start();
      now = now.add(const Duration(minutes: 6));
      game.tick();
      expect(game.timedOut, isTrue);
      expect(game.practiceMode, isTrue);
      game.dispose();
    });

    test('finishing records the run, and a replay is never sent to be scored', () async {
      final lib = libraryWith([samplePuzzle(id: 'today', publishDate: '2026-10-28')]);
      final game = gameWith(lib, signedIn: true);
      game.start();
      for (final id in [1, 2, 3]) {
        game.revealRow(id);
      }
      game.revealRow(finalRowId);
      expect(game.completed, isTrue);
      expect(game.hintsUsed, 4);
      expect(game.records.finished('today'), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(calls, contains('scores/submit'));

      calls.clear();
      game.resetPuzzle();
      expect(game.playedBefore, isTrue);
      game.start();
      game.revealRow(finalRowId);
      await Future<void>.delayed(Duration.zero);
      expect(calls, isNot(contains('scores/submit')));
      game.dispose();
    });

    test('hints come from the dictionary offline, one level at a time', () async {
      final game = gameWith(libraryWith([samplePuzzle(id: 'today', publishDate: '2026-10-28')]));
      game.start();
      await game.requestHint(1);
      await game.requestHint(1);
      expect(game.hintsFor(1).texts, ['It means: slightly open.', 'It starts with A and ends with R, with 2 vowels.']);
      expect(game.hintsUsed, 2);
      expect(game.hintTarget(null), 1);
      game.dispose();
    });

    test("a newly published sheet replaces the day's slot unless a run is underway", () {
      final lib = libraryWith([samplePuzzle(id: 'y', publishDate: '2026-10-27')]);
      final game = gameWith(lib);
      expect(game.standingIn, isTrue);
      lib.debugSet(
        published: [
          samplePuzzle(id: 'today', publishDate: '2026-10-28'),
          samplePuzzle(id: 'y', publishDate: '2026-10-27'),
        ],
        bundled: [samplePuzzle(id: 'bundled', publishDate: '2026-07-18')],
      );
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      lib.notifyListeners();
      expect(game.puzzle.id, 'today');

      game.start();
      lib.debugSet(
        published: [samplePuzzle(id: 'other', publishDate: '2026-10-28')],
      );
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      lib.notifyListeners();
      expect(game.puzzle.id, 'today', reason: 'nobody loses a run to a download');
      game.dispose();
    });
  });

  group('shake', () {
    test('a shake reshuffles without touching the timer or the hints', () {
      final game = gameWith(libraryWith([samplePuzzle(id: 'today', publishDate: '2026-10-28')]));
      game.start();
      now = now.add(const Duration(seconds: 30));
      game.tick();
      game.revealRow(3);
      final seconds = game.remainingSeconds;
      final hints = game.hintsUsed;
      final word2 = game.board.row(2)!.letters;
      expect(game.rescramble(), isTrue);
      expect(game.board.row(2)!.letters, isNot(word2));
      expect(game.board.row(3)!.letters, 'STAY');
      expect(game.remainingSeconds, seconds);
      expect(game.hintsUsed, hints);
      game.dispose();
    });

    test('nothing to jumble before the run starts', () {
      final game = gameWith(libraryWith([samplePuzzle(id: 'today', publishDate: '2026-10-28')]));
      expect(game.rescramble(), isFalse);
      expect(game.board.row(1)!.letters, 'RAJA');
    });
  });
}
