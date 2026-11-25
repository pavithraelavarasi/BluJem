import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/answer_shape.dart';
import '../models/puzzle.dart';
import '../models/records.dart';
import 'api_client.dart';

/// Three hints per word and per final answer, each giving away more.
///
/// The AI (jumble_ai, when signed in and configured on the server) words them
/// when it can; the bundled glossary always can, so a hint is never missing.
/// A hint that spells out the answer is thrown away — a leaked answer is worse
/// than a dull clue.
class HintService {
  HintService(this._api, this._signedIn, {Future<String> Function()? loadGlossary})
    : _loadGlossary = loadGlossary ?? (() => rootBundle.loadString('assets/data/glosses.txt'));

  static const levels = 3;

  final ApiClient _api;
  final bool Function() _signedIn;
  final Future<String> Function() _loadGlossary;
  Future<Map<String, String>>? _glossary;

  Future<Map<String, String>> get glossary =>
      _glossary ??= _loadGlossary().then((text) => compute(parseGlossary, text));

  /// What [word] means, from the bundled glossary; null when it has none.
  Future<String?> meaningOf(String word) async {
    final meaning = (await glossary)[word.toUpperCase()];
    if (meaning == null || meaning.trim().isEmpty) return null;
    final text = meaning.trim();
    return text[0].toUpperCase() + text.substring(1);
  }

  Future<Hint> wordHint(Puzzle puzzle, PuzzleWord word, int level, List<String> previous) async {
    if (_signedIn()) {
      final reply = await _api.tryPost(
        JumbleFunction.ai,
        'jumble/hint',
        body: {
          'puzzleId': puzzle.id,
          'wordId': word.id,
          'answer': word.answer,
          'scrambled': word.scrambled,
          'level': level,
          'previousHints': previous,
        },
      );
      final text = '${reply?['hint'] ?? ''}'.trim();
      if (text.isNotEmpty && !leaks(text, word.answer)) return Hint(text, HintSource.ai);
    }
    return Hint(_at(wordLadder(word, await glossary), level), HintSource.offline);
  }

  Future<Hint> finalHint(Puzzle puzzle, int level, List<String> previous, String circledLetters) async {
    if (_signedIn()) {
      final reply = await _api.tryPost(
        JumbleFunction.ai,
        'final/hint',
        body: {
          'puzzleId': puzzle.id,
          'answer': puzzle.finalAnswer,
          'clue': puzzle.finalClue,
          'circledLetters': circledLetters,
          'level': level,
          'previousHints': previous,
        },
      );
      final text = '${reply?['hint'] ?? ''}'.trim();
      if (text.isNotEmpty && !leaks(text, puzzle.finalAnswerLetters)) return Hint(text, HintSource.ai);
    }
    return Hint(_at(finalLadder(puzzle, await glossary), level), HintSource.offline);
  }

  static String _at(List<String> ladder, int level) =>
      ladder.isEmpty ? '' : ladder[(level - 1).clamp(0, ladder.length - 1)];

  /// Whether [hint] contains [answer]'s letters in a run.
  static bool leaks(String hint, String answer) {
    final plain = lettersOf(answer);
    return plain.isNotEmpty && lettersOf(hint).contains(plain);
  }

  /// What it means, how it starts and ends, then every other letter.
  static List<String> wordLadder(PuzzleWord word, Map<String, String> glossary) {
    final answer = word.answer.toUpperCase();
    if (answer.isEmpty) return const [];
    final meaning = glossary[answer];
    final circled = word.circles.where((c) => c).length;
    final vowels = answer.split('').where('AEIOU'.contains).length;
    return [
      meaning != null
          ? 'It means: $meaning.'
          : 'It is a ${answer.length}-letter word, and $circled of its letters carry into the final answer.',
      'It starts with ${answer[0]} and ends with ${answer[answer.length - 1]}, '
          'with $vowels vowel${vowels == 1 ? '' : 's'}.',
      [for (var i = 0; i < answer.length; i++) i.isEven ? answer[i] : '_'].join(' '),
    ];
  }

  /// Its shape, what the last word (which carries the joke) means, then each
  /// word's first letter.
  static List<String> finalLadder(Puzzle puzzle, Map<String, String> glossary) {
    final parts = puzzle.finalAnswer
        .toUpperCase()
        .split(RegExp(r'\s+'))
        .map(lettersOf)
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return const [];
    final shape = parts.map((p) => p.length).join(' + ');
    final head = parts.last;
    final meaning = glossary[head];
    return [
      'The answer is ${parts.length} word${parts.length == 1 ? '' : 's'} ($shape letters), '
          'and uses every circled letter exactly once.',
      meaning != null ? 'The last word means: $meaning.' : 'The last word has ${head.length} letters.',
      parts.map((p) => [for (var i = 0; i < p.length; i++) i == 0 ? p[i] : '_'].join(' ')).join('   '),
    ];
  }
}

/// One `WORD<TAB>meaning` per line.
Map<String, String> parseGlossary(String text) {
  final out = <String, String>{};
  for (final line in text.split('\n')) {
    final tab = line.indexOf('\t');
    if (tab > 0) out[line.substring(0, tab)] = line.substring(tab + 1).trimRight();
  }
  return out;
}
