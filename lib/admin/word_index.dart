import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';

/// The word list, indexed by sorted letters, with how common each word is —
/// so unscrambling a printed word is one map lookup.
///
/// Each line is a three-digit rank and the word, `016PARTY`: lower is
/// commoner, and 999 means the word is not on the ranked list at all. Words
/// of three to eight letters are ranked, as Jumble words are never longer;
/// longer ones, unranked, are there for the Sunday Jumble's long answers.
class WordIndex {
  WordIndex(Iterable<String> lines) {
    for (final line in lines) {
      if (line.length <= 3) continue;
      final word = line.substring(3);
      final rank = int.tryParse(line.substring(0, 3)) ?? 999;
      (_byLetters[_key(word)] ??= []).add((word: word, rank: rank));
    }
    // Cartoon answers lean on the little words the list leaves out.
    for (final (word, rank) in _shortWords) {
      (_byLetters[_key(word)] ??= []).add((word: word, rank: rank));
    }
    // The S of a possessive, CREW'S, printed as a square of its own.
    (_byLetters['S'] ??= []).add((word: 'S', rank: 300));
    for (final entries in _byLetters.values) {
      entries.sort((a, b) => a.rank.compareTo(b.rank));
    }
  }

  /// One- and two-letter words with how common each is: the everyday ones
  /// as common as any word, the rest well behind.
  static const _shortWords = [
    ('A', 5), ('I', 5), ('TO', 5), ('OF', 5), ('IN', 5), ('IS', 5), ('IT', 5), ('ON', 5), ('AT', 5), //
    ('AS', 10), ('BE', 10), ('BY', 10), ('AN', 10), ('OR', 10), ('SO', 10), ('UP', 10), ('NO', 10), //
    ('DO', 15), ('GO', 15), ('HE', 15), ('WE', 15), ('ME', 15), ('MY', 15), ('US', 15), ('IF', 15), ('AM', 20), //
    ('OH', 150), ('OK', 150), ('OX', 200),
  ];

  final _byLetters = <String, List<({String word, int rank})>>{};

  static Future<WordIndex>? _loading;

  /// The bundled index, built once in the background.
  static Future<WordIndex> load() => _loading ??= () async {
    final data = await rootBundle.load('assets/admin/words.txt.gz');
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    return Isolate.run(() => WordIndex(const LineSplitter().convert(utf8.decode(gzip.decode(bytes)))));
  }();

  static String _key(String letters) => (letters.toUpperCase().split('')..sort()).join();

  /// Every word these letters make, commonest first.
  List<String> unscramble(String letters) {
    final cleaned = letters.toUpperCase().replaceAll(RegExp('[^A-Z]'), '');
    if (cleaned.length < 3) return const [];
    return [for (final e in _byLetters[_key(cleaned)] ?? const []) e.word];
  }

  /// The one word these letters plainly make, or null when it is a toss-up:
  /// taken only when it is strictly commoner than the runner-up.
  String? best(String letters) {
    final cleaned = letters.toUpperCase().replaceAll(RegExp('[^A-Z]'), '');
    final entries = _byLetters[_key(cleaned)] ?? const [];
    if (entries.isEmpty) return null;
    if (entries.length == 1 || entries[0].rank < entries[1].rank) return entries[0].word;
    return null;
  }
}

extension PhraseSolver on WordIndex {
  /// Phrases spelled with exactly [letters], one word per entry of [groups]
  /// (letters per word, as the answer row prints them), commonest first.
  ///
  /// Each word is a choice of letters looked up whole, so this never scans
  /// the list. With no [groups], one word or two are tried. With [spare],
  /// that many of [letters] are left over — for letters read in error.
  List<({String phrase, int score})> phrases(String letters, List<int> groups, {int limit = 8, int spare = 0}) {
    final pool = (letters.toUpperCase().replaceAll(RegExp('[^A-Z]'), '').split('')..sort()).join();
    if (pool.isEmpty) return const [];
    final shapes = groups.isNotEmpty
        ? [groups]
        : [
            [pool.length - spare],
            for (var k = 2; k <= pool.length - spare - 2; k++) [k, pool.length - spare - k],
          ];
    final found = <String, int>{};
    var budget = 200000;

    void search(List<int> shape, int at, String left, List<({String word, int rank})> words) {
      if (budget-- <= 0) return;
      if (at == shape.length) {
        if (left.length == spare) {
          final score = words.fold(0, (a, w) => a + w.rank) + _misplaced(words.map((w) => w.word).toList());
          found[words.map((w) => w.word).join(' ')] = score;
        }
        return;
      }
      for (final pick in _choices(left, shape[at])) {
        final entries = _byLetters[pick.$1];
        if (entries == null) continue;
        // The commonest few spellings are enough; obscure ones only crowd the list.
        for (final e in entries.take(3)) {
          search(shape, at + 1, pick.$2, [...words, e]);
        }
      }
    }

    for (final shape in shapes) {
      if (shape.fold(0, (a, b) => a + b) != pool.length - spare || shape.any((n) => n < 1)) continue;
      search(shape, 0, pool, const []);
    }
    // The same words in another order score the same; they keep the order
    // they were found in, which a stable sort needs the index for.
    final entries = found.entries.toList();
    final ranked = [for (var i = 0; i < entries.length; i++) (i, entries[i])]
      ..sort((a, b) {
        final byScore = a.$2.value.compareTo(b.$2.value);
        return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
      });
    return [for (final (_, e) in ranked.take(limit)) (phrase: e.key, score: e.value)];
  }

  /// Words a phrase cannot start with, and words it cannot end with.
  static const _neverFirst = {'AND', 'OR', 'NOR', 'BUT', 'S'};
  static const _neverLast = {
    'AND',
    'OR',
    'NOR',
    'BUT',
    'THE',
    'A',
    'AN',
    'OF',
    'TO',
    'AT',
    'BY',
    'FOR',
    'FROM',
    'WITH',
  };

  /// How much less likely [words] is for a joining word in the wrong place:
  /// AND CUT DRY or CUT DRY AND go well behind CUT AND DRY.
  static int _misplaced(List<String> words) {
    if (words.length < 2) return 0;
    var cost = 0;
    if (_neverFirst.contains(words.first)) cost += 400;
    if (_neverLast.contains(words.last)) cost += 400;
    return cost;
  }

  /// Every distinct way to take [n] of the sorted [letters]: what is taken and what is left, both sorted.
  static Iterable<(String, String)> _choices(String letters, int n) sync* {
    if (n == 0) {
      yield ('', letters);
      return;
    }
    for (var i = 0; i <= letters.length - n; i++) {
      // A repeated letter is only started from once, so no choice comes out twice.
      if (i > 0 && letters[i] == letters[i - 1]) continue;
      for (final rest in _choices(letters.substring(i + 1), n - 1)) {
        yield (letters[i] + rest.$1, letters.substring(0, i) + rest.$2);
      }
    }
  }
}

/// Whether [a] and [b] use exactly the same letters.
bool sameLetters(String a, String b) {
  String key(String s) => (s.toUpperCase().replaceAll(RegExp('[^A-Z]'), '').split('')..sort()).join();
  return key(a) == key(b);
}
