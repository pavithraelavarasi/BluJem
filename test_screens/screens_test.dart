// ignore_for_file: invalid_use_of_visible_for_testing_member
// Renders the main screens to PNGs for design review, with a fake local
// session and no network: `flutter test test_screens --update-goldens`.
import 'dart:convert';
import 'dart:io';

import 'package:blujem/data/api_client.dart';
import 'package:blujem/data/auth_repository.dart';
import 'package:blujem/data/hint_service.dart';
import 'package:blujem/data/local_store.dart';
import 'package:blujem/data/puzzle_library.dart';
import 'package:blujem/data/records_repository.dart';
import 'package:blujem/data/score_repository.dart';
import 'package:blujem/data/social_sign_in.dart';
import 'package:blujem/game/game_controller.dart';
import 'package:blujem/models/puzzle.dart';
import 'package:blujem/ui/app.dart';
import 'package:blujem/ui/feedback.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> loadFonts() async {
  final fredoka = FontLoader('Fredoka')..addFont(rootBundle.load('assets/fonts/Fredoka.ttf'));
  await fredoka.load();
  final sdk = Platform.environment['FLUTTER_ROOT'] ?? '${Platform.environment['HOME']}/development/flutter';
  final icons = File('$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('screens', (tester) async {
    await initializeDateFormatting();
    await loadFonts();
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;

    final now = DateTime.now();
    String day(int back) => now.subtract(Duration(days: back)).toIso8601String().substring(0, 10);
    SharedPreferences.setMockInitialValues({
      'account': jsonEncode({'id': 'u1', 'email': 'sam@example.com', 'name': 'Sam Rivera', 'username': 'samr', 'role': 'player', 'token': 't'}),
      'completions_u1': jsonEncode({
        'completed': [
          for (var i = 1; i <= 3; i++)
            {'puzzleId': 'x$i', 'sheetDate': '', 'finalAnswer': '', 'seconds': 90 + i * 20, 'hintsUsed': i - 1,
              'completedAt': now.subtract(Duration(days: i)).millisecondsSinceEpoch},
        ],
      }),
    });
    final store = await LocalStore.forTest(Directory.systemTemp.createTempSync('shots'));
    final api = ApiClient(http: MockClient((req) async {
      final route = req.url.path.split('/execute/').last;
      return switch (route) {
        'scores/leaderboard' => http.Response(jsonEncode({
            'entries': [
              {'rank': 1, 'key': 'a', 'name': 'wordwiz', 'points': 4820, 'puzzles': 31},
              {'rank': 2, 'key': 'b', 'name': 'jumblejane', 'points': 4410, 'puzzles': 29},
              {'rank': 3, 'key': 'c', 'name': 'samr', 'points': 3900, 'puzzles': 24, 'you': true},
              {'rank': 4, 'key': 'd', 'name': 'anagramma', 'points': 3120, 'puzzles': 22},
            ],
            'me': {'rank': 3, 'points': 3900, 'puzzles': 24},
          }), 200),
        _ => http.Response('{}', 500),
      };
    }));
    final auth = AuthRepository(api, store, const NoSocialSignIn());
    final bundled = jsonDecode(File('assets/bundled/puzzles.json').readAsStringSync())['puzzles'] as List;
    final today = Puzzle.fromJson({...Map<String, dynamic>.from(bundled[2]), 'id': 'today', 'publishDate': day(0)});
    final library = PuzzleLibrary(api, store)
      ..debugSet(published: [today], bundled: [for (final p in bundled) Puzzle.fromJson(Map<String, dynamic>.from(p))]);
    final records = RecordsRepository(api, store);
    await records.switchAccount('u1');
    final scores = ScoreRepository(api, () => true);
    final hints = HintService(api, () => false, loadGlossary: () async => 'PARTY\ta social gathering');
    final game = GameController(library: library, records: records, scores: scores, hints: hints);
    final feedback = GameFeedback(store)..toggleMuted();

    Future<void> shot(String name) async {
      await tester.pump(const Duration(milliseconds: 600));
      await expectLater(find.byType(BluJemApp), matchesGoldenFile('shots/$name.png'));
    }

    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: library),
      ChangeNotifierProvider.value(value: records),
      ChangeNotifierProvider.value(value: game),
      ChangeNotifierProvider.value(value: feedback),
      Provider.value(value: scores),
    ], child: const BluJemApp()));
    await tester.pump();
    await tester.pump();
    await shot('1_home');

    await tester.tap(find.text('Play now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await shot('2_start');

    game.start();
    // Word 1 (TRPYA → PARTY) part-formed: P, A.
    game.tapLetter(1, 2); // TRPYA → PTRYA
    game.tapLetter(1, 4); // → PATRY
    game.revealRow(2);
    await tester.pump();
    await shot('3_board');

    await tester.tap(find.text('Hint'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await shot('4_hint');
    await tester.tap(find.text('Close'));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('See Cartoon'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
    await tester.pump(const Duration(milliseconds: 500));
    await shot('5_cartoon');

    await tester.tap(find.text('See Words'));
    await tester.pump(const Duration(milliseconds: 500));
    for (final id in [1, 3, 4]) {
      game.revealRow(id);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await shot('5b_final_ready');

    game.revealRow(-1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 600));
    await shot('6_done');

    await tester.tap(find.text('Done'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('History'));
    await tester.pump(const Duration(milliseconds: 500));
    await shot('7_history');
    await tester.tap(find.text('Ranks'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(milliseconds: 500));
    await shot('8_ranks');
    await tester.tap(find.text('Profile'));
    await tester.pump(const Duration(milliseconds: 500));
    await shot('9_profile');
    game.dispose();
  });
}
