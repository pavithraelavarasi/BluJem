import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../core/slots.dart';
import 'answer_shape.dart';
import 'box_rect.dart';

/// Where a sheet image is: shipped with the app, or downloaded to disk.
class SheetImage {
  const SheetImage.asset(this.path) : isAsset = true;
  const SheetImage.file(this.path) : isAsset = false;

  final String path;
  final bool isAsset;
}

/// One scrambled word: its printed letters, its answer and the squares the
/// answer goes in. Squares matter for which ones are circled.
class PuzzleWord {
  const PuzzleWord({
    required this.id,
    required this.scrambled,
    required this.answer,
    required this.boxes,
    this.answerHash = '',
  });

  final int id;
  final String scrambled;

  /// Empty for a player until they need it: the server sends only
  /// [answerHash] to check their letters against.
  final String answer;
  final List<BoxRect> boxes;
  final String answerHash;

  int get length => answer.isNotEmpty ? answer.length : scrambled.length;

  /// Which squares are circled, left to right.
  List<bool> get circles => [for (final b in boxes) b.circled];

  /// The letters this word gives the final answer, left to right.
  List<String> get bonusLetters => [
    for (var i = 0; i < boxes.length && i < answer.length; i++)
      if (boxes[i].circled) answer[i],
  ];

  PuzzleWord withAnswer(String value) =>
      PuzzleWord(id: id, scrambled: scrambled, answer: value, boxes: boxes, answerHash: answerHash);

  Map<String, dynamic> toJson() => {
    'scrambled': scrambled,
    'answer': answer,
    if (answerHash.isNotEmpty) 'answerHash': answerHash,
    'boxes': [for (final b in boxes) b.toJson()],
  };
}

/// The server's hash of an answer: sha256 of the puzzle's id and the letters
/// alone (jumble_data/lib/puzzle-views.js answerHash), so the phone can tell
/// a right answer without ever being sent it.
String answerHash(String puzzleId, String letters, {bool isFinal = false}) =>
    sha256.convert(utf8.encode('$puzzleId:${isFinal ? 'final:' : ''}${lettersOf(letters)}')).toString();

/// A daily puzzle: a sheet image, its words (four, or six on a Sunday) and the
/// cartoon's final answer.
///
/// One model for every source — the server's list, the on-device cache and
/// the bundled samples — so they can never drift apart.
class Puzzle {
  const Puzzle({
    required this.id,
    required this.publishDate,
    required this.sheetDate,
    required this.difficulty,
    required this.timeLimitSeconds,
    required this.image,
    required this.aspectRatio,
    required this.words,
    required this.finalAnswer,
    required this.finalBoxes,
    required this.finalClue,
    required this.finalExplanation,
    this.published = true,
    this.cartoonCrop,
    this.slot = '',
    this.publishAt = 0,
    this.finalPattern = '',
    this.finalHash = '',
    this.sheetKey = '',
  });

  final String id;

  /// The day this sheet is served, yyyy-MM-dd.
  final String publishDate;

  /// The date printed on the sheet, e.g. "Jul 18".
  final String sheetDate;
  final String difficulty;
  final int timeLimitSeconds;
  final SheetImage image;
  final double aspectRatio;
  final bool published;
  final List<PuzzleWord> words;

  /// As printed, punctuation included: `"CREW'S" SHIP`.
  final String finalAnswer;
  final List<BoxRect> finalBoxes;
  final String finalClue;
  final String finalExplanation;

  /// Where the cartoon is on the sheet, when known ahead of time.
  final BoxRect? cartoonCrop;

  /// morning, evening (the afternoon), night or sunday; empty for a sheet from before slots.
  final String slot;

  /// When it went (or goes) live, epoch ms; 0 when not known.
  final int publishAt;

  /// The answer boxes with their punctuation, a new line where it wraps:
  /// `"□□□□□-\n□□□□□" □□□`.
  final String finalPattern;

  /// For a player, the final answer's hash in place of [finalAnswer].
  final String finalHash;

  /// Where the picture is kept on the server.
  final String sheetKey;

  Slot get slotKind => Slot.tryParse(slot) ?? Slot.defaultFor(publishDate);

  /// When it goes live: as stored, or for an older sheet its day's first slot.
  DateTime get releasedAt => publishAt > 0
      ? DateTime.fromMillisecondsSinceEpoch(publishAt, isUtc: true)
      : (DateTime.tryParse(publishDate) == null ? DateTime.utc(1970) : slotStart(publishDate, slotKind));

  /// The answers are not on the phone: words are checked by hash.
  bool get answersHidden => finalAnswer.isEmpty && finalHash.isNotEmpty;

  /// What the answer row prints: the answer, or its pattern with a letter
  /// stand-in for each box — the same squares and punctuation either way.
  String get finalShapeText => finalAnswer.isNotEmpty
      ? finalAnswer
      : finalPattern.replaceAll('□', 'X').replaceAll('-\n', '-').replaceAll('\n', ' ');

  /// How many squares the answer row has.
  int get finalLetterCount => finalAnswer.isNotEmpty ? finalAnswerLetters.length : '□'.allMatches(finalPattern).length;

  /// Groups of the answer row per line where the pattern wraps; empty when
  /// it does not say.
  List<int> get finalLineBreaks {
    if (!finalPattern.contains('\n')) return const [];
    final out = <int>[];
    var groups = 0;
    for (final line in finalPattern.split('\n')) {
      groups += RegExp('□+').allMatches(line).length;
      out.add(groups);
    }
    return out..removeLast();
  }

  /// The final answer as printed, from the letters the player put in.
  String finalFrom(String letters) {
    if (finalAnswer.isNotEmpty) return finalAnswer;
    var i = 0;
    return finalPattern
        .replaceAllMapped(RegExp('□'), (_) => i < letters.length ? letters[i++] : '□')
        .replaceAll('-\n', '-')
        .replaceAll('\n', ' ');
  }

  /// This puzzle with the server's answers filled in.
  Puzzle withAnswers(List<String> answers, String finalAnswer, String explanation) => _copy(
    words: [for (var i = 0; i < words.length; i++) i < answers.length ? words[i].withAnswer(answers[i]) : words[i]],
    finalAnswer: finalAnswer.toUpperCase(),
    finalExplanation: explanation,
  );

  /// Stored as just its cartoon picture, the page built from the letters
  /// when shown: the picture's file name ends in -cartoon.
  bool get cartoonOnly => RegExp(r'-cartoon\.\w+$').hasMatch(image.path);

  /// What the player actually spells: letters only.
  String get finalAnswerLetters => lettersOf(finalAnswer);

  /// The answer row's groups of squares.
  List<int> get finalGroups => AnswerShape.groupsFor(finalShapeText, finalLetterCount);

  DateTime? get day => DateTime.tryParse(publishDate);

  /// What stops the sheet being played: a missing answer, or one that does
  /// not fit its squares. Sheets with problems are never offered.
  List<String> get problems => [
    for (var i = 0; i < words.length; i++)
      if (words[i].answer.isEmpty && words[i].answerHash.isEmpty)
        'Word ${i + 1} has no answer yet.'
      else if (words[i].length != words[i].boxes.length)
        'Word ${i + 1} does not fit its squares.',
    if (finalAnswer.trim().isEmpty && finalHash.isEmpty) 'The final answer is empty.',
    if ((finalAnswer.trim().isNotEmpty || finalHash.isNotEmpty) && finalLetterCount != finalBoxes.length)
      'The final answer does not fit its squares.',
  ];

  bool get isPlayable => words.isNotEmpty && problems.isEmpty;

  Puzzle withImage(SheetImage image) => _copy(image: image);

  Puzzle _copy({SheetImage? image, List<PuzzleWord>? words, String? finalAnswer, String? finalExplanation}) => Puzzle(
    id: id,
    publishDate: publishDate,
    sheetDate: sheetDate,
    difficulty: difficulty,
    timeLimitSeconds: timeLimitSeconds,
    image: image ?? this.image,
    aspectRatio: aspectRatio,
    words: words ?? this.words,
    finalAnswer: finalAnswer ?? this.finalAnswer,
    finalBoxes: finalBoxes,
    finalClue: finalClue,
    finalExplanation: finalExplanation ?? this.finalExplanation,
    published: published,
    cartoonCrop: cartoonCrop,
    slot: slot,
    publishAt: publishAt,
    finalPattern: finalPattern,
    finalHash: finalHash,
    sheetKey: sheetKey,
  );

  /// Reads the server's row (whose lists arrive as JSON text), the local
  /// cache and the bundled file alike. [image] overrides the stored path.
  factory Puzzle.fromJson(Map<String, dynamic> j, {SheetImage? image}) {
    List<dynamic> list(Object? v) {
      if (v is List) return v;
      if (v is String && v.isNotEmpty) {
        final decoded = jsonDecode(v);
        if (decoded is List) return decoded;
      }
      return const [];
    }

    List<BoxRect> boxes(Object? v) => [for (final b in list(v)) BoxRect.fromJson(Map<String, dynamic>.from(b as Map))];

    final words = list(j['words']);
    final publishDate = '${j['publishDate'] ?? ''}';
    final path = '${j['image'] ?? j['imagePath'] ?? ''}';
    final crop = j['cartoonCrop'];
    return Puzzle(
      id: '${j['id'] ?? ''}',
      publishDate: publishDate,
      sheetDate: '${j['sheetDate'] ?? ''}'.isEmpty ? publishDate : '${j['sheetDate']}',
      difficulty: '${j['difficulty'] ?? 'Easy'}',
      timeLimitSeconds: (j['timeLimitSeconds'] as num?)?.toInt() ?? 300,
      image: image ?? (path.startsWith('assets/') ? SheetImage.asset(path) : SheetImage.file(path)),
      aspectRatio: (j['aspectRatio'] as num?)?.toDouble() ?? 1,
      published: j['published'] != false,
      words: [
        for (var i = 0; i < words.length; i++)
          PuzzleWord(
            id: i + 1,
            scrambled: '${words[i]['scrambled'] ?? ''}'.toUpperCase(),
            answer: '${words[i]['answer'] ?? ''}'.toUpperCase(),
            answerHash: '${words[i]['answerHash'] ?? ''}',
            boxes: boxes(words[i]['boxes']),
          ),
      ],
      finalAnswer: '${j['finalAnswer'] ?? ''}'.toUpperCase(),
      finalBoxes: boxes(j['finalBoxes'])..sort((a, b) => a.x.compareTo(b.x)),
      finalClue: '${j['finalClue'] ?? ''}',
      finalExplanation: '${j['finalExplanation'] ?? ''}',
      cartoonCrop: crop is Map ? BoxRect.fromJson(Map<String, dynamic>.from(crop)) : null,
      slot: '${j['slot'] ?? ''}',
      publishAt: (j['publishAt'] as num?)?.toInt() ?? 0,
      finalPattern: '${j['finalPattern'] ?? ''}',
      finalHash: '${j['finalHash'] ?? ''}',
      sheetKey: '${j['sheetKey'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'publishDate': publishDate,
    'sheetDate': sheetDate,
    'difficulty': difficulty,
    'timeLimitSeconds': timeLimitSeconds,
    'image': image.path,
    'aspectRatio': aspectRatio,
    'published': published,
    'words': [for (final w in words) w.toJson()],
    'finalAnswer': finalAnswer,
    'finalBoxes': [for (final b in finalBoxes) b.toJson()],
    'finalClue': finalClue,
    'finalExplanation': finalExplanation,
    if (cartoonCrop != null) 'cartoonCrop': cartoonCrop!.toJson(),
    'slot': slot,
    'publishAt': publishAt,
    'finalPattern': finalPattern,
    'finalHash': finalHash,
    'sheetKey': sheetKey,
  };
}
