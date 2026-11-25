import 'dart:convert';
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

/// 25 Nov 2026's afternoon puzzle as a player gets it (answers as hashes).
/// [finalAnswer] is what the server holds; the admin corrected it once.
const _id = '3c5543a0-69e4-44d6-bfc5-10447b0d99ed';
const _words = {
  'FIWE': ('WIFE', [0, 2, 3]),
  'DUGYA': ('GAUDY', [0, 1, 3]),
  'WORSRO': ('SORROW', [0, 1, 2, 4]),
  'EMOONSE': ('SOMEONE', [0, 1]),
};

Map<String, dynamic> playerJson(String finalAnswer, String version, {String image = ''}) {
  Map<String, dynamic> box(bool c) => {'x': 0, 'y': 0, 'w': 0, 'h': 0, if (c) 'c': true};
  return {
    'id': _id,
    'publishDate': '2026-11-25',
    'slot': 'evening',
    'publishAt': DateTime.utc(2026, 11, 25, 9, 30).millisecondsSinceEpoch,
    'sheetKey': 'puzzles/2026-11-25/evening/cartoon.png',
    'sheetVersion': version,
    'published': true,
    'timeLimitSeconds': 300,
    'finalAnswer': '',
    'finalPattern': '□□□ □□□, □□ □□□□',
    'finalHash': answerHash(_id, finalAnswer, isFinal: true),
    'finalBoxes': [for (var i = 0; i < 12; i++) box(true)],
    'words': [
      for (final e in _words.entries)
        {
          'scrambled': e.key,
          'answerHash': answerHash(_id, e.value.$1),
          'boxes': [for (var i = 0; i < e.value.$1.length; i++) box(e.value.$2.contains(i))],
        },
    ],
    if (image.isNotEmpty) 'image': image,
  };
}

Board formAll(Board b, int id, String text) {
  for (var k = 0; k < text.length; k++) {
    b = b.form(id, b.row(id)!.letters.indexOf(text[k], k));
  }
  return b;
}

Board playedUp(Board b) {
  var i = 1;
  for (final w in _words.values) {
    b = formAll(b, i++, w.$1);
  }
  return formAll(b, finalRowId, 'SEWFARSOGOOD');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final before = Puzzle.fromJson(playerJson('SOW FAR, SE GOOD', 'v1')); // the answer before the admin fixed it
  final fixed = Puzzle.fromJson(playerJson('SEW FAR, SO GOOD', 'v2'));

  test('the right answer is refused by the old copy, and accepted once the correction carries over', () {
    final b = playedUp(Board.start(before));
    expect(b.allWordsSolved, isTrue);
    expect(b.finalRow.letters, 'SEWFARSOGOOD');
    expect(b.finalRow.solved, isFalse);

    final carried = b.withChecksFrom(fixed)!;
    expect(carried.finalRow.letters, 'SEWFARSOGOOD', reason: 'letters stay where the player put them');
    expect(carried.finalRow.solved, isTrue);
    expect(carried.allWordsSolved, isTrue);
  });

  test("a copy with different letters can't carry over", () {
    final other = Puzzle.fromJson(
      playerJson('SEW FAR, SO GOOD', 'v2')
        ..['words'] = [
          for (final w in playerJson('X', 'v2')['words'] as List)
            {...(w as Map), 'scrambled': 'ABCDEFG'.substring(0, (w['scrambled'] as String).length)},
        ],
    );
    expect(Board.start(before).withChecksFrom(other), isNull);
  });

  group('in a game', () {
    late LocalStore store;
    late ApiClient api;
    final now = DateTime.utc(2026, 11, 25, 10, 45); // 4:15 PM in India
    DateTime clock() => now;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = await LocalStore.forTest(Directory.systemTemp.createTempSync('fix'));
      api = ApiClient(http: MockClient((req) async => http.Response('{}', 500)));
    });

    test('a game under way finishes once the admin fixes the answer', () {
      final library = PuzzleLibrary(api, store, clock: clock)..debugSet(published: [before]);
      final game = GameController(
        library: library,
        records: RecordsRepository(api, store, clock: clock),
        scores: ScoreRepository(api, () => false),
        hints: HintService(api, () => false, loadGlossary: () async => ''),
        clock: clock,
      );
      game.openPuzzle(before);
      game.start();
      var i = 1;
      for (final w in _words.values) {
        for (var k = 0; k < w.$1.length; k++) {
          game.tapLetter(i, game.board.row(i)!.letters.indexOf(w.$1[k], k));
        }
        i++;
      }
      for (var k = 0; k < 12; k++) {
        game.tapLetter(finalRowId, game.board.finalRow.letters.indexOf('SEWFARSOGOOD'[k], k));
      }
      expect(game.completed, isFalse, reason: 'the old copy refuses it');

      library.debugSet(published: [fixed]);
      expect(game.completed, isTrue);
      expect(game.board.finalRow.letters, 'SEWFARSOGOOD');
      game.dispose();
    });

    test("an edited puzzle stays in History when its new picture can't come down yet", () async {
      final picture = File('${store.folder('sheets').path}/old-cartoon.png')..writeAsBytesSync([1, 2, 3]);
      final api = ApiClient(
        http: MockClient((req) async {
          final route = req.url.path.split('/execute/').last;
          if (route == 'puzzles/list') {
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'puzzles': [playerJson('SEW FAR, SO GOOD', 'v2')],
                }),
              ),
              200,
            );
          }
          return http.Response('{}', 500); // the new picture fails
        }),
      );
      final library = PuzzleLibrary(api, store, clock: clock)
        ..debugSet(published: [before.withImage(SheetImage.file(picture.path))]);
      await library.sync();
      expect(library.available.map((p) => p.id), [_id]);
      expect(library.available.single.sheetVersion, 'v2', reason: 'the corrected answers');
      expect(library.available.single.image.path, picture.path, reason: 'the picture already here');
    });
  });
}
