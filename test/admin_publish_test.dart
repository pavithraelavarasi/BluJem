import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:blujem/admin/admin_service.dart';
import 'package:blujem/admin/word_index.dart';
import 'package:blujem/core/dates.dart';
import 'package:blujem/data/api_client.dart';
import 'package:blujem/data/local_store.dart';
import 'package:blujem/data/puzzle_library.dart';
import 'package:blujem/models/box_rect.dart';
import 'package:blujem/models/puzzle.dart';
import 'package:blujem/ui/screens/admin_screen.dart';
import 'package:blujem/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A day the server read with three circles missed: the paper circles 13
/// squares (5 + 8 answer squares), the server saw 10.
DailyPuzzle _misread() {
  List<BoxRect> row(int n, double y, Set<int> circled) => [
    for (var j = 0; j < n; j++) BoxRect(0.05 + j * 0.06, y, 0.05, 0.07, circled: circled.contains(j)),
  ];
  return DailyPuzzle(
    date: '2026-10-29',
    status: 'NEEDS_REVIEW',
    scrambles: const ['OHNIR', 'ETFRA', 'ERMGEE', 'SCTUAC'],
    clue: 'He did have a —',
    groups: const [5, 8],
    squares: [
      row(5, 0.3, {1, 4}), // paper: 1, 2, 4
      row(5, 0.45, {2, 4}), // paper: 2, 3, 4
      row(6, 0.6, {1, 4, 5}),
      row(6, 0.75, {1, 3, 5}), // paper: 1, 3, 4, 5
    ],
    collageAspect: 1.4,
    assets: const {DailyPuzzle.collage: 'collage'},
    problems: const ['10 circled squares but 13 answer boxes; one of them was misread.'],
  );
}

/// Today's puzzle as the server read it: COHORT's C and T circled in error,
/// 15 circles for the 13 squares of HEAD OFF TO WORK.
DailyPuzzle _today() {
  List<BoxRect> row(int n, double y, Set<int> circled) => [
    for (var j = 0; j < n; j++) BoxRect(0.05 + j * 0.06, y, 0.05, 0.07, circled: circled.contains(j)),
  ];
  return DailyPuzzle(
    date: '2026-10-30',
    status: 'NEEDS_REVIEW',
    scrambles: const ['TNEFO', 'EFWRA', 'KONYDE', 'OCTHRO'],
    clue: "Sleepy Hollow's legendary rider liked relaxing before he would —",
    groups: const [4, 3, 2, 4],
    squares: [
      row(5, 0.3, {1, 2, 3}),
      row(5, 0.45, {0, 1, 2}),
      row(6, 0.6, {0, 1, 3}),
      row(6, 0.75, {0, 1, 2, 3, 4, 5}), // paper: 1, 2, 3, 4
    ],
    collageAspect: 1.4,
    assets: const {DailyPuzzle.collage: 'collage'},
    problems: const [],
  );
}

/// The Sunday Jumble of 2026-11-01 as the server reads it: six words of six letters.
DailyPuzzle _sunday() {
  List<BoxRect> row(double y, Set<int> circled) => [
    for (var j = 0; j < 6; j++) BoxRect(0.05 + j * 0.06, y, 0.05, 0.07, circled: circled.contains(j)),
  ];
  return DailyPuzzle(
    date: '2026-11-01',
    status: 'NEEDS_REVIEW',
    scrambles: const ['EOLMPC', 'IKIBNI', 'NCYOTO', 'CCESNI', 'LOLFWO', 'ITREMP'],
    clue: 'When he thought back to his demolition derby days, it was a —',
    groups: const [5, 10],
    squares: [
      row(0.20, {1, 4, 5}),
      row(0.32, {1, 2}),
      row(0.44, {2, 3, 5}),
      row(0.56, {1, 5}),
      row(0.68, {3, 5}),
      row(0.80, {1, 2, 5}),
    ],
    collageAspect: 1.32,
    assets: const {DailyPuzzle.collage: 'collage'},
    problems: const [],
  );
}

/// The publish screen for [day], against a server whose AI has no key.
///
/// Every call is added to [calls]; [published] is what players have now.
Future<void> _open(
  WidgetTester tester,
  DailyPuzzle day,
  Map<String, String> picks, {
  List<(String, Map<String, dynamic>)>? calls,
  List<Puzzle> published = const [],
  Uint8List? cartoon,
}) async {
  SharedPreferences.setMockInitialValues({});
  final png = img.encodePng(img.Image(width: 14, height: 10));
  final api = ApiClient(
    http: MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      calls?.add((request.url.pathSegments.last, body));
      return switch (request.url.pathSegments.last) {
        'list' => http.Response(jsonEncode({'puzzles': []}), 200),
        'daily-asset' => http.Response(jsonEncode({'key': 'collage', 'base64': base64Encode(png)}), 200),
        'select-answer' => http.Response(jsonEncode({'answer': picks[body['scrambled']]}), 200),
        'solve' => http.Response(jsonEncode({'error': 'AI is not configured.'}), 503),
        _ => http.Response('{}', 200),
      };
    }),
  );
  final library = PuzzleLibrary(api, await LocalStore.forTest(Directory.systemTemp.createTempSync('admin')))
    ..debugSet(published: published);
  await tester.binding.setSurfaceSize(const Size(500, 3000));
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider.value(value: AdminService(api)),
        ChangeNotifierProvider.value(value: library),
      ],
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: PublishScreen(day: day, cartoon: cartoon),
      ),
    ),
  );
}

/// [day] with the circles the paper prints, on a date ahead so it is the one offered.
DailyPuzzle _onChristmas(DailyPuzzle day, {List<List<BoxRect>>? squares}) => DailyPuzzle(
  date: '2026-12-25',
  status: day.status,
  scrambles: day.scrambles,
  clue: day.clue,
  groups: day.groups,
  squares: squares ?? day.squares,
  collageAspect: day.collageAspect,
  assets: day.assets,
  problems: day.problems,
);

/// What players have on Christmas Day now: published with a wrong answer.
Puzzle _liveChristmas() => const Puzzle(
  id: 'old-id',
  publishDate: '2026-12-25',
  sheetDate: '',
  difficulty: 'Easy',
  timeLimitSeconds: 300,
  image: SheetImage.file('/cache/sheets/old-id.png'),
  aspectRatio: 1.2,
  words: [
    PuzzleWord(id: 0, scrambled: 'TNEFO', answer: 'OFTEN', boxes: [BoxRect(0.1, 0.2, 0.05, 0.07, circled: true)]),
  ],
  finalAnswer: 'CLOCK ELECTROWIN',
  finalBoxes: [BoxRect(0.1, 0.9, 0.05, 0.07, circled: true)],
  finalClue: 'A clue —',
  finalExplanation: '',
);

/// Lets the background word list and the server replies land until [done].
Future<void> _settle(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 60 && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
}

void main() {
  // Loaded once, outside any one test: the word list is shared, and a load
  // begun inside a test's fake clock never wakes the tests after it.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await WordIndex.load();
  });

  testWidgets('with no AI, the dictionary suggests the answer, and fixing the circles makes it sure', (tester) async {
    await _open(tester, _today(), const {});
    final field = find.widgetWithText(TextField, 'Final answer, as printed (13 letters: 4 + 3 + 2 + 4)');
    String answer() => tester.widget<TextField>(field).controller!.text;
    final today = find.widgetWithText(ChoiceChip, 'HEAD OFF TO WORK');
    await _settle(tester, () => today.evaluate().isNotEmpty);

    // Two circles too many: the phrases are guesses, offered but not filled in.
    expect(today, findsOneWidget);
    expect(answer(), isEmpty);
    expect(find.textContaining("circles don't match the paper"), findsOneWidget);
    expect(find.textContaining('No suggestion'), findsNothing);

    // Tapping the answer fits the circles to it.
    await tester.tap(today);
    await tester.pump();
    expect(answer(), 'HEAD OFF TO WORK');
    expect(find.text('Circled letters: FTEWAFDOKOHOR'), findsOneWidget);
    expect(find.textContaining('squares are circled but the answer'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('circles that match the paper get the answer first', (tester) async {
    final read = _today();
    final day = DailyPuzzle(
      date: read.date,
      status: read.status,
      scrambles: read.scrambles,
      clue: read.clue,
      groups: read.groups,
      squares: [
        ...read.squares.take(3),
        [for (final (j, b) in read.squares[3].indexed) BoxRect(b.x, b.y, b.w, b.h, circled: j >= 1 && j <= 4)],
      ],
      collageAspect: read.collageAspect,
      assets: read.assets,
      problems: read.problems,
    );
    await _open(tester, day, const {});
    final field = find.widgetWithText(TextField, 'Final answer, as printed (13 letters: 4 + 3 + 2 + 4)');
    await _settle(tester, () => tester.widget<TextField>(field).controller!.text.isNotEmpty);
    expect(tester.widget<TextField>(field).controller!.text, 'HEAD OFF TO WORK');
    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a typed puzzle suggests its answer with the hyphens the paper prints', (tester) async {
    List<BoxRect> row(int n, double y, Set<int> circled) => [
      for (var j = 0; j < n; j++) BoxRect(0.05 + j * 0.06, y, 0.05, 0.07, circled: circled.contains(j)),
    ];
    final day = DailyPuzzle(
      date: '2026-11-05',
      status: 'TYPED',
      scrambles: const ['ADRRA', 'TUYPT', 'HCNRCU', 'CRAOCD'],
      clue: "There's nothing complicated about making beef jerky. The process is —",
      groups: const [3, 3, 3],
      joins: const ['-', '-'],
      squares: [
        row(5, 0.3, {1, 2}),
        row(5, 0.45, {2, 4}),
        row(6, 0.6, {2, 3}),
        row(6, 0.75, {1, 4, 5}),
      ],
      collageAspect: 1.4,
      assets: const {DailyPuzzle.collage: 'collage'},
      problems: const [],
    );
    final calls = <(String, Map<String, dynamic>)>[];
    final cartoon = img.encodePng(img.Image(width: 30, height: 40));
    await _open(tester, day, const {}, calls: calls, cartoon: cartoon);
    final field = find.widgetWithText(TextField, 'Final answer, as printed (9 letters: 3 + 3 + 3)');
    await _settle(tester, () => tester.widget<TextField>(field).controller!.text.isNotEmpty);
    expect(tester.widget<TextField>(field).controller!.text, 'CUT-AND-DRY');

    // Only the cartoon is stored, named so the players' app builds the page.
    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await _settle(tester, () => calls.any((c) => c.$1 == 'publish'));
    final sent = calls.firstWhere((c) => c.$1 == 'publish').$2;
    expect(sent['sheetKey'], endsWith('-cartoon.jpg'));
    expect(base64Decode(sent['sheetBase64'] as String), cartoon);
    expect(sent['finalAnswer'], 'CUT-AND-DRY');
    expect(calls.where((c) => c.$1 == 'daily-asset'), isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('publish is ready once the words and the final answer are in, clue or not', (tester) async {
    List<BoxRect> row(int n, double y, Set<int> circled) => [
      for (var j = 0; j < n; j++) BoxRect(0.05 + j * 0.06, y, 0.05, 0.07, circled: circled.contains(j)),
    ];
    final day = DailyPuzzle(
      date: '2026-11-05',
      status: 'TYPED',
      scrambles: const ['ADRRA', 'TUYPT', 'HCNRCU', 'CRAOCD'],
      clue: '',
      groups: const [3, 3, 3],
      joins: const ['-', '-'],
      squares: [
        row(5, 0.3, {1, 2}),
        row(5, 0.45, {2, 4}),
        row(6, 0.6, {2, 3}),
        row(6, 0.75, {1, 4, 5}),
      ],
      collageAspect: 1.4,
      assets: const {},
      problems: const [],
    );
    await _open(tester, day, const {}, cartoon: img.encodePng(img.Image(width: 30, height: 40)));
    final field = find.widgetWithText(TextField, 'Final answer, as printed (9 letters: 3 + 3 + 3)');
    await _settle(tester, () => tester.widget<TextField>(field).controller!.text.isNotEmpty);
    FilledButton publish() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Publish'));
    expect(publish().onPressed, isNotNull);

    await tester.enterText(field, '');
    await tester.pump();
    expect(publish().onPressed, isNull);
    expect(find.text('Type the final answer to publish.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a published puzzle can be unpublished and republished from the Upload page', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final calls = <(String, Map<String, dynamic>)>[];
    final api = ApiClient(
      http: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        calls.add((request.url.pathSegments.last, body));
        return switch (request.url.pathSegments.last) {
          'list' => http.Response(jsonEncode({'puzzles': [], 'days': []}), 200),
          _ => http.Response('{}', 200),
        };
      }),
    );
    final library = PuzzleLibrary(api, await LocalStore.forTest(Directory.systemTemp.createTempSync('admin')))
      ..debugSet(published: [_liveChristmas()]);
    await tester.binding.setSurfaceSize(const Size(500, 2000));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: AdminService(api)),
          ChangeNotifierProvider.value(value: library),
        ],
        child: MaterialApp(theme: buildTheme(Brightness.light), home: const AdminScreen()),
      ),
    );
    await tester.pump();
    expect(find.textContaining('CLOCK ELECTROWIN'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Unpublish'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Unpublish'));
    await _settle(tester, () => find.widgetWithText(OutlinedButton, 'Republish').evaluate().isNotEmpty);
    final down = calls.lastWhere((c) => c.$1 == 'publish').$2;
    expect([down['id'], down['published']], ['old-id', false]);
    expect(find.text('Unpublished'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Republish'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Republish'));
    await _settle(tester, () => find.textContaining('is published again').evaluate().isNotEmpty);
    final up = calls.lastWhere((c) => c.$1 == 'publish').$2;
    expect([up['id'], up['published']], ['old-id', true]);
    expect(library.takenDown, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a Sunday Jumble opens with all six words and its long answer suggested', (tester) async {
    await _open(tester, _sunday(), const {});
    final field = find.widgetWithText(TextField, 'Final answer, as printed (15 letters: 5 + 10)');
    final chip = find.widgetWithText(ChoiceChip, 'WRECK COLLECTION');
    String answer() => tester.widget<TextField>(field).controller!.text;
    await _settle(tester, () => answer() == 'WRECK COLLECTION' || chip.evaluate().isNotEmpty);

    for (final s in ['EOLMPC', 'IKIBNI', 'NCYOTO', 'CCESNI', 'LOLFWO', 'ITREMP']) {
      expect(find.text('$s  →  answer'), findsOneWidget);
    }
    expect(find.text('Circled letters: OELIKCONCCLWERT'), findsOneWidget);
    expect(answer() == 'WRECK COLLECTION' || chip.evaluate().isNotEmpty, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a published day can be unpublished, which frees it', (tester) async {
    final calls = <(String, Map<String, dynamic>)>[];
    await _open(tester, _onChristmas(_today()), const {}, calls: calls, published: [_liveChristmas()]);
    await tester.pump();
    expect(find.textContaining('is published now, answer CLOCK ELECTROWIN'), findsOneWidget);
    expect(find.text('Replace published puzzle'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Unpublish'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Unpublish'));
    await _settle(tester, () => find.textContaining('is unpublished').evaluate().isNotEmpty);

    final sent = calls.where((c) => c.$1 == 'publish').single.$2;
    expect(sent['id'], 'old-id');
    expect(sent['published'], false);
    expect(sent['sheetKey'], 'sheets/old-id.png', reason: 'the sheet is kept as it was');
    expect(sent['finalAnswer'], 'CLOCK ELECTROWIN', reason: 'nothing else changes');
    expect(find.textContaining('is published now'), findsNothing);
    expect(find.text('Publish'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets("a past day that was published opens on its own date, not today's", (tester) async {
    final past = _liveChristmas();
    final yesterday = isoDate(dateOnly(DateTime.now()).subtract(const Duration(days: 1)));
    final live = Puzzle.fromJson({...past.toJson(), 'publishDate': yesterday}, image: past.image);
    final day = _today();
    await _open(
      tester,
      DailyPuzzle(
        date: yesterday,
        status: day.status,
        scrambles: day.scrambles,
        clue: day.clue,
        groups: day.groups,
        squares: day.squares,
        collageAspect: day.collageAspect,
        assets: day.assets,
        problems: day.problems,
      ),
      const {},
      published: [live],
    );
    await tester.pump();
    expect(find.text('Publish for ${longDate(yesterday)}'), findsOneWidget);
    expect(
      find.textContaining(RegExp('${monthDay(DateTime.parse(yesterday))} (morning|mega blujem) is published now')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('publishing over a published day replaces it with a new puzzle', (tester) async {
    final calls = <(String, Map<String, dynamic>)>[];
    final read = _today();
    final day = _onChristmas(
      read,
      squares: [
        ...read.squares.take(3),
        [for (final (j, b) in read.squares[3].indexed) BoxRect(b.x, b.y, b.w, b.h, circled: j >= 1 && j <= 4)],
      ],
    );
    await _open(tester, day, const {}, calls: calls, published: [_liveChristmas()]);
    final field = find.widgetWithText(TextField, 'Final answer, as printed (13 letters: 4 + 3 + 2 + 4)');
    await _settle(tester, () => tester.widget<TextField>(field).controller!.text.isNotEmpty);
    expect(tester.widget<TextField>(field).controller!.text, 'HEAD OFF TO WORK');

    await tester.tap(find.text('Replace published puzzle'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Replace'));
    await _settle(tester, () => calls.where((c) => c.$1 == 'publish').length >= 2);

    final published = [
      for (final c in calls)
        if (c.$1 == 'publish') c.$2,
    ];
    expect(published.first['published'], true);
    expect(published.first['finalAnswer'], 'HEAD OFF TO WORK');
    expect(published.first['id'], isNot('old-id'), reason: 'a new puzzle, so phones fetch its sheet');
    expect(published.last['id'], 'old-id');
    expect(published.last['published'], false);
    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('typing the answer circles the squares the server missed', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final png = img.encodePng(img.Image(width: 14, height: 10));
    const picks = {'OHNIR': 'RHINO', 'ETFRA': 'AFTER', 'ERMGEE': 'EMERGE', 'SCTUAC': 'CACTUS'};
    final api = ApiClient(
      http: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final reply = switch (request.url.pathSegments.last) {
          'daily-asset' => {'key': 'collage', 'base64': base64Encode(png)},
          'select-answer' => {'answer': picks[body['scrambled']]},
          _ => <String, dynamic>{},
        };
        return http.Response(jsonEncode(reply), 200);
      }),
    );
    final library = PuzzleLibrary(api, await LocalStore.forTest(Directory.systemTemp.createTempSync('admin')));

    await tester.binding.setSurfaceSize(const Size(500, 3000));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: AdminService(api)),
          ChangeNotifierProvider.value(value: library),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: PublishScreen(day: _misread()),
        ),
      ),
    );
    // The word list loads in a background isolate.
    for (var i = 0; i < 40 && find.text('Circled letters: HOTRMGEATS').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    expect(find.text('Circled letters: HOTRMGEATS'), findsOneWidget);
    expect(find.textContaining('prints 13 answer squares but 10'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Final answer, as printed (13 letters: 5 + 8)'),
      'ROUGH ESTIMATE',
    );
    await tester.pump();

    expect(find.text('Circled letters: HIOTERMGEATUS'), findsOneWidget);
    expect(find.textContaining('prints 13 answer squares but'), findsNothing);
    expect(find.textContaining('squares are circled but the answer'), findsNothing);
    expect(find.textContaining('check them against the paper'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  });
}
