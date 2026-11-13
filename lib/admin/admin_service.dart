import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../data/api_client.dart';
import '../models/box_rect.dart';
import '../models/puzzle.dart';

/// One day's puzzle as the daily processor prepared it: read off the
/// newspaper by the Zia agent, drawn as a BluJem collage and checked. Never
/// solved — the words are scrambles until the admin fills the answers in.
class DailyPuzzle {
  const DailyPuzzle({
    required this.date,
    required this.status,
    required this.scrambles,
    required this.clue,
    required this.groups,
    required this.squares,
    required this.collageAspect,
    required this.assets,
    required this.problems,
    this.failure,
    this.joins = const [],
  });

  static const collage = 'collage-letters.png';

  /// yyyy-MM-dd — the day it is for.
  final String date;

  /// RENDERED, NEEDS_REVIEW, STALE_SOURCE or FAILED.
  final String status;
  final List<String> scrambles;

  /// The clue as printed, ending in a dash.
  final String clue;

  /// Letters per word of the final answer, e.g. [5, 2, 6].
  final List<int> groups;

  /// What the paper prints between those words: a space, or a hyphen as in
  /// CUT-AND-DRY. Empty when not known.
  final List<String> joins;

  /// Every square on the collage, as fractions of it — exact, since it was drawn.
  final List<List<BoxRect>> squares;
  final double collageAspect;

  /// Stored file keys by name.
  final Map<String, String> assets;

  /// Failed checks and validation problems, for the admin to read.
  final List<String> problems;
  final String? failure;

  /// Ready to become a puzzle: drawn, with every square known.
  bool get canDraft => assets.containsKey(collage) && scrambles.isNotEmpty && squares.length == scrambles.length;

  static DailyPuzzle? fromJson(Map<String, dynamic> o) {
    final date = '${o['date'] ?? ''}';
    if (date.isEmpty) return null;
    final extraction = o['extraction'] is Map ? Map<String, dynamic>.from(o['extraction'] as Map) : const {};
    final layout = o['layout'] is Map ? Map<String, dynamic>.from(o['layout'] as Map) : const {};
    List<Map> maps(Object? v) => v is List ? v.whereType<Map>().toList() : const [];
    List<int> ints(Object? v) => v is List
        ? [
            for (final n in v)
              if (n is num) n.toInt(),
          ]
        : const [];
    String messages(Map m) => '${m['message'] ?? ''}';

    final finalAnswer = extraction['finalAnswer'];
    final width = (layout['width'] as num?)?.toDouble() ?? 1800;
    final height = (layout['height'] as num?)?.toDouble() ?? 1361;
    final error = o['error'];
    return DailyPuzzle(
      date: date,
      status: '${o['status'] ?? ''}',
      scrambles: [for (final w in maps(extraction['words'])) '${w['scrambled'] ?? ''}'.toUpperCase()],
      clue: '${o['clue'] ?? ''}'.isNotEmpty ? '${o['clue']}' : '${extraction['finalClue'] ?? ''}',
      groups: finalAnswer is Map ? ints(finalAnswer['groups']) : const [],
      joins: finalAnswer is Map && finalAnswer['betweenGroups'] is List
          ? [for (final m in finalAnswer['betweenGroups'] as List) '$m'.trim().isEmpty ? ' ' : '$m'.trim()]
          : const [],
      squares: [
        for (final row in (layout['words'] is List ? layout['words'] as List : const []))
          [
            for (final b in maps(row))
              BoxRect(
                (b['x'] as num).toDouble(),
                (b['y'] as num).toDouble(),
                (b['w'] as num).toDouble(),
                (b['h'] as num).toDouble(),
                circled: b['circled'] == true,
              ),
          ],
      ],
      collageAspect: width / height,
      assets: o['assets'] is Map ? {for (final e in (o['assets'] as Map).entries) '${e.key}': '${e.value}'} : const {},
      problems: [
        ...maps(o['errors']).map(messages),
        ...maps(o['warnings']).map(messages),
        ...maps(o['checks']).where((c) => c['ok'] != true).map(messages),
      ].where((m) => m.isNotEmpty).toList(),
      failure: error is Map ? '${error['message'] ?? ''}' : null,
    );
  }
}

/// A puzzle ready to publish: the sheet image with its answer row drawn, and
/// everything the players' app needs to play it.
class PublishSheet {
  const PublishSheet({
    required this.publishDate,
    this.slot = '',
    this.finalPattern = '',
    required this.image,
    required this.aspectRatio,
    required this.words,
    required this.finalAnswer,
    required this.finalBoxes,
    required this.finalGroups,
    required this.finalClue,
    required this.finalExplanation,
    this.cartoonOnly = false,
  });

  final String publishDate;

  /// morning, evening (the afternoon), night or sunday.
  final String slot;

  /// The answer boxes as typed, line breaks kept; empty when not typed.
  final String finalPattern;

  /// The sheet, or with [cartoonOnly] just the cartoon: the players' app
  /// builds the page from the words.
  final Uint8List image;
  final bool cartoonOnly;
  final double aspectRatio;
  final List<({String scrambled, String answer, List<BoxRect> boxes})> words;
  final String finalAnswer;
  final List<BoxRect> finalBoxes;
  final List<int> finalGroups;
  final String finalClue;
  final String finalExplanation;
}

/// [picture] made smaller to send: a JPEG no wider than 2000 pixels, which
/// the agent reads as well as the original PNG at about a third of the size.
/// Kept as it is when that would not be smaller, or it cannot be read.
Future<Uint8List> shrinkForUpload(Uint8List picture) => Isolate.run(() {
  final decoded = img.decodeImage(picture);
  if (decoded == null) return picture;
  final sized = decoded.width > 2000 ? img.copyResize(decoded, width: 2000) : decoded;
  final jpeg = img.encodeJpg(sized, quality: 85);
  return jpeg.length < picture.length ? jpeg : picture;
});

/// The admin's calls: the daily processor (blujem_daily), the AI helpers
/// (jumble_ai) and publishing (jumble_data). Each checks the admin role on
/// the server; nothing here is trusted on its own.
class AdminService {
  AdminService(this._api);

  final ApiClient _api;

  /// Sends the newspaper puzzle (1-3 images) to be read and drawn; the request to follow.
  Future<String> start(List<Uint8List> images, {String? date}) async {
    final reply = await _api.post(
      JumbleFunction.daily,
      'process-daily-test',
      body: {
        'images': [
          for (final i in images) {'base64': base64Encode(i)},
        ],
        'expectedDate': ?date,
      },
      timeout: const Duration(seconds: 60),
    );
    final id = '${reply['requestId'] ?? ''}';
    if (id.isEmpty) throw const ApiException('The daily processor could not start.');
    return id;
  }

  /// PENDING until the request is done, then RENDERED, NEEDS_REVIEW, STALE_SOURCE or FAILED.
  Future<String> status(String requestId) async {
    final reply = await _api.post(JumbleFunction.daily, 'process-daily-result', body: {'requestId': requestId});
    return '${reply['status'] ?? 'PENDING'}';
  }

  /// Every prepared day, newest first.
  Future<List<DailyPuzzle>> list() async {
    final reply = await _api.post(JumbleFunction.daily, 'daily-list');
    final rows = reply['puzzles'] is List ? reply['puzzles'] as List : const [];
    return [for (final r in rows.whereType<Map>()) ?DailyPuzzle.fromJson(Map<String, dynamic>.from(r))];
  }

  /// One stored image of a prepared day.
  Future<Uint8List> asset(String key) async {
    final reply = await _api.post(
      JumbleFunction.daily,
      'daily-asset',
      body: {'key': key},
      timeout: const Duration(seconds: 60),
    );
    final data = '${reply['base64'] ?? ''}';
    if (data.isEmpty) throw const ApiException('The image could not be downloaded.');
    return base64Decode(data);
  }

  /// The AI's pick among dictionary words that fit a scramble.
  Future<String?> pickWord(String scrambled, List<String> candidates, String clue) async {
    final reply = await _api.tryPost(
      JumbleFunction.ai,
      'jumble/select-answer',
      body: {'scrambled': scrambled, 'candidates': candidates, 'clue': clue},
    );
    final answer = '${reply?['answer'] ?? ''}'.toUpperCase();
    return answer.isEmpty ? null : answer;
  }

  /// The AI's reading of the cartoon answer; only ever one spelled with exactly the circled letters.
  Future<({String answer, String explanation})?> solveFinal({
    required String circled,
    required List<int> groups,
    required String clue,
    required List<String> solvedWords,
  }) async {
    final reply = await _api.tryPost(
      JumbleFunction.ai,
      'final/solve',
      body: {
        'circledLetters': circled,
        'clue': clue,
        'solvedWords': solvedWords,
        if (groups.isNotEmpty) 'groupSizes': groups,
      },
    );
    final answer = '${reply?['answer'] ?? ''}';
    if (answer.isEmpty || answer == 'null') return null;
    return (answer: answer.toUpperCase(), explanation: '${reply?['explanation'] ?? ''}');
  }

  /// Publishes [sheet] as a new puzzle; players get it on its date.
  Future<void> publish(PublishSheet sheet) async {
    final id = _newId();
    await _api.post(
      JumbleFunction.data,
      'puzzles/publish',
      body: {
        'id': id,
        // The name tells the players' app the picture is only the cartoon.
        if (sheet.cartoonOnly) 'sheetKey': 'sheets/$id-cartoon.jpg',
        'publishDate': sheet.publishDate,
        'slot': sheet.slot,
        'finalPattern': sheet.finalPattern,
        'sheetDate': '',
        'difficulty': 'Easy',
        'timeLimitSeconds': 300,
        'aspectRatio': sheet.aspectRatio,
        'published': true,
        'finalAnswer': sheet.finalAnswer,
        'finalClue': sheet.finalClue,
        'finalExplanation': sheet.finalExplanation,
        'finalBoxes': jsonEncode([for (final b in sheet.finalBoxes) b.toJson()]),
        'finalGroupSizes': jsonEncode(sheet.finalGroups),
        'words': jsonEncode([
          for (final w in sheet.words)
            {
              'scrambled': w.scrambled,
              'answer': w.answer,
              'boxes': [for (final b in w.boxes) b.toJson()],
            },
        ]),
        'sheetBase64': base64Encode(sheet.image),
      },
      timeout: const Duration(seconds: 90),
    );
  }

  /// Takes [puzzle] down: players stop seeing it and its date is free again.
  /// The row is kept, unpublished, exactly as it was.
  Future<void> unpublish(Puzzle puzzle) => _setPublished(puzzle, false);

  /// Puts an unpublished [puzzle] back, exactly as it was.
  Future<void> republish(Puzzle puzzle) => _setPublished(puzzle, true);

  Future<void> _setPublished(Puzzle puzzle, bool published) async {
    await _api.post(
      JumbleFunction.data,
      'puzzles/publish',
      body: {
        'id': puzzle.id,
        'publishDate': puzzle.publishDate,
        'slot': puzzle.slot,
        'finalPattern': puzzle.finalPattern,
        'sheetDate': puzzle.sheetDate,
        'difficulty': puzzle.difficulty,
        'timeLimitSeconds': puzzle.timeLimitSeconds,
        'aspectRatio': puzzle.aspectRatio,
        'published': published,
        // Sheets are stored as sheets/<file> and downloaded under that file's name.
        'sheetKey': puzzle.sheetKey.isNotEmpty
            ? puzzle.sheetKey
            : (puzzle.image.isAsset ? '' : 'sheets/${puzzle.image.path.split('/').last}'),
        'finalAnswer': puzzle.finalAnswer,
        'finalClue': puzzle.finalClue,
        'finalExplanation': puzzle.finalExplanation,
        'finalBoxes': jsonEncode([for (final b in puzzle.finalBoxes) b.toJson()]),
        'finalGroupSizes': jsonEncode(puzzle.finalGroups),
        'words': jsonEncode([
          for (final w in puzzle.words)
            {
              'scrambled': w.scrambled,
              'answer': w.answer,
              'boxes': [for (final b in w.boxes) b.toJson()],
            },
        ]),
      },
    );
  }

  static String _newId() {
    final r = Random.secure();
    String hex(int n) => [for (var i = 0; i < n; i++) r.nextInt(16).toRadixString(16)].join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-${(8 + r.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(12)}';
  }
}
