import 'dart:math';

import '../models/puzzle.dart';

/// [answerHash] under a name rows can call without their own field hiding it.
String answerHashOf(String puzzleId, String letters, {bool isFinal = false}) =>
    answerHash(puzzleId, letters, isFinal: isFinal);

/// Row id of the final-answer row, which is not one of the numbered words.
const finalRowId = -1;

/// The most letter moves kept for undo.
const maxUndo = 50;

/// One row of letter squares: a word, or the final answer.
///
/// Every row is a [pool] of letters and an [order] saying which pool letter
/// sits in each square. Moves only ever reorder, so a letter keeps its
/// identity (the two S's of SISKDE stay apart) and undo is just an old order.
///
/// The final row's pool is the circled letters of the words, with a blank for
/// each circle of a word not solved yet — so it follows the words as they are
/// solved, the way the paper has you copy circled letters down.
class RowState {
  const RowState({
    required this.id,
    required this.answer,
    required this.pool,
    required this.order,
    this.circles = const [],
    this.solved = false,
    this.revealed = false,
    this.answerHash = '',
    this.puzzleId = '',
    this.fixed = const {},
  });

  final int id;

  /// Squares a hint put right: their letters stay put through taps, drags,
  /// Mix, Reset and a shake, and Undo never takes them back.
  final Set<int> fixed;

  /// Letters only, upper case. Empty while the server keeps the answers:
  /// the row is then checked against [answerHash].
  final String answer;
  final String answerHash;

  /// What the hash is salted with.
  final String puzzleId;
  final String pool;
  final List<int> order;

  /// Which squares are circled (word rows only).
  final List<bool> circles;
  final bool solved;
  final bool revealed;

  bool get isFinal => id == finalRowId;
  int get length => order.length;

  /// What the row spells now, with a space for an empty square.
  String get letters => order.map((i) => pool[i]).join();

  bool get isBlank => letters.trim().isEmpty;

  /// Up to the first empty square: what can be formed in the answer row.
  int get formable {
    final gap = letters.indexOf(' ');
    return gap >= 0 ? gap : length;
  }

  RowState copyWith({
    String? pool,
    List<int>? order,
    bool? solved,
    bool? revealed,
    String? answer,
    String? answerHash,
    Set<int>? fixed,
  }) => RowState(
    id: id,
    answer: answer ?? this.answer,
    pool: pool ?? this.pool,
    order: order ?? this.order,
    circles: circles,
    solved: solved ?? this.solved,
    revealed: revealed ?? this.revealed,
    answerHash: answerHash ?? this.answerHash,
    puzzleId: puzzleId,
    fixed: fixed ?? this.fixed,
  );

  /// Whether [text] is the answer, by the answer itself or by its hash.
  bool spells(String text) {
    if (answer.isNotEmpty) return text == answer;
    if (answerHash.isEmpty || text.contains(' ')) return false;
    return answerHash == answerHashOf(puzzleId, text, isFinal: isFinal);
  }

  /// [order] with the letter in square [from] moved to [to], the letters
  /// between sliding along, and the [fixed] squares left where they are.
  List<int> movedAround(int from, int to) => order.movedAround(from, to, fixed);

  /// The first square from [i] on that a tap can fill: past the fixed ones.
  int nextOpen(int i) {
    while (i < length && fixed.contains(i)) {
      i++;
    }
    return i;
  }

  /// This row with [order], solved the moment it spells the answer.
  RowState checked(List<int> order) {
    final next = copyWith(order: order);
    return next.copyWith(solved: next.spells(next.letters));
  }
}

/// What one move changed, so it can be taken back.
class UndoStep {
  const UndoStep(this.rowId, this.order, this.formed);
  final int rowId;
  final List<int> order;
  final int formed;
}

/// The letters on a puzzle and every way the player can move them.
///
/// Immutable and free of timers, sound and network: every action returns the
/// next board (or this one, when nothing changed), which is what makes the
/// rules testable on their own.
class Board {
  const Board({
    required this.words,
    required this.finalRow,
    required this.follows,
    this.formed = const {},
    this.undo = const [],
  });

  final List<RowState> words;
  final RowState finalRow;

  /// True when the circled letters add up to the final answer, so the answer
  /// row follows the words. False for a misread sheet, whose answer row then
  /// starts with the answer's own letters, mixed.
  final bool follows;

  /// How many letters at the front of each row the player has formed.
  final Map<int, int> formed;
  final List<UndoStep> undo;

  factory Board.start(Puzzle puzzle) {
    final words = [
      for (final w in puzzle.words)
        () {
          final pool = startingLetters(w.scrambled, w.answer);
          return RowState(
            id: w.id,
            answer: w.answer,
            pool: pool,
            order: List.generate(pool.length, (i) => i),
            circles: w.circles,
            answerHash: w.answerHash,
            puzzleId: puzzle.id,
          );
        }(),
    ];
    final answer = puzzle.finalAnswerLetters;
    final circled = circledLetters(words);
    final follows = circled.length == puzzle.finalLetterCount;
    final pool = follows ? circled : startingLetters(puzzle.words.expand((w) => w.bonusLetters).join(), answer);
    return Board(
      words: words,
      finalRow: RowState(
        id: finalRowId,
        answer: answer,
        pool: pool,
        order: List.generate(pool.length, (i) => i),
        answerHash: puzzle.finalHash,
        puzzleId: puzzle.id,
      ),
      follows: follows,
    );
  }

  /// This board with the answers the server sent in place of their hashes;
  /// every letter stays where the player put it.
  Board withAnswers(Puzzle puzzle) {
    RowState fill(RowState r, String answer) => r.answer.isNotEmpty || answer.isEmpty ? r : r.copyWith(answer: answer);
    return Board(
      words: [for (final w in words) fill(w, puzzle.words.where((p) => p.id == w.id).firstOrNull?.answer ?? '')],
      finalRow: fill(finalRow, puzzle.finalAnswerLetters),
      follows: follows,
      formed: formed,
      undo: undo,
    );
  }

  /// This board checked against [fresh], an admin's corrected copy of the
  /// same puzzle: every letter stays where the player put it, and a row that
  /// already spells the corrected answer counts as solved. Null when the
  /// copy's letters or squares differ, so this board cannot carry over.
  Board? withChecksFrom(Puzzle fresh) {
    final next = Board.start(fresh);
    if (next.words.length != words.length || next.follows != follows) return null;
    String sorted(String s) => (s.split('')..sort()).join();
    RowState? carry(RowState mine, RowState theirs) {
      if (mine.id != theirs.id || mine.length != theirs.length || mine.circles.join() != theirs.circles.join()) {
        return null;
      }
      // A word's letters are fixed by the sheet; the answer row's follow the words.
      if (!mine.isFinal && sorted(mine.pool) != sorted(theirs.pool)) return null;
      final r = mine.copyWith(answer: theirs.answer, answerHash: theirs.answerHash);
      return r.revealed ? r : r.copyWith(solved: r.spells(r.letters));
    }

    final carried = <RowState>[];
    for (var i = 0; i < words.length; i++) {
      final r = carry(words[i], next.words[i]);
      if (r == null) return null;
      carried.add(r);
    }
    final last = carry(finalRow, next.finalRow);
    if (last == null) return null;
    return Board(words: carried, finalRow: last, follows: follows, formed: formed, undo: undo);
  }

  // ------------------------------------------------------------- reading

  List<RowState> get rows => [...words, finalRow];

  RowState? row(int id) =>
      id == finalRowId ? finalRow : words.cast<RowState?>().firstWhere((w) => w!.id == id, orElse: () => null);

  bool get allWordsSolved => words.isNotEmpty && words.every((w) => w.solved);
  int get solvedCount => words.where((w) => w.solved).length;
  bool get canUndo => undo.isNotEmpty;
  int formedIn(int id) => formed[id] ?? 0;

  /// Letters carried to the final answer so far, '?' for unsolved words.
  String get bonusLetters => [
    for (final w in words)
      for (var i = 0; i < w.circles.length; i++)
        if (w.circles[i]) (w.solved ? w.letters[i] : '?'),
  ].join();

  // ------------------------------------------------------------- moving

  /// Moves the letter in square [from] to square [to]; the letters between
  /// slide along (never a swap): GTANR with its R moved second is GRTAN.
  Board move(int id, int from, int to) {
    final r = row(id);
    if (r == null || r.solved || from == to || r.isBlank) return this;
    if (from < 0 || to < 0 || from >= r.length || to >= r.length) return this;
    final order = r.movedAround(from, to);
    if (_same(order, r.order)) return this;
    return _replace(r.checked(order), pushUndo: r);
  }

  /// Tap-to-form: the tapped letter joins the front of the row, after those
  /// already formed. RAJA → tap A, J, A → AJAR. Tapping a formed letter takes
  /// the row back to just before it.
  Board form(int id, int index) {
    final r = row(id);
    if (r == null || r.solved || index < 0 || index >= r.length) return this;
    if (r.letters[index] == ' ' || r.fixed.contains(index)) return this;

    final done = r.nextOpen(min(formedIn(id), r.formable));
    if (index < done) return _withFormed(id, index);

    final moved = index == done ? this : move(id, index, done);
    final after = moved.row(id)!;
    if (after.solved) return moved;
    final open = after.formable;
    var next = after.nextOpen(done + 1);
    // With one letter left, it can only go in the last open square.
    final left = [for (var i = next; i < after.length; i++) i].where((i) => !after.fixed.contains(i)).length;
    if (open == after.length && left <= 1) next = after.length;
    return moved._withFormed(id, min(next, open));
  }

  /// A letter dragged from [from] to [to]. Letters formed before the first
  /// square it touched stay formed; from there on they do not.
  Board drag(int id, int from, int to) {
    final before = formedIn(id);
    final next = move(id, from, to);
    if (identical(next, this)) return this;
    final touched = min(from, to);
    return touched < before ? next._withFormed(id, touched) : next;
  }

  /// Puts a row back as it started.
  Board reset(int id) {
    final r = row(id);
    if (r == null || r.solved) return this;
    // As printed, but for the squares a hint fixed.
    final kept = {for (final p in r.fixed) r.order[p]};
    final rest = [
      for (var i = 0; i < r.length; i++)
        if (!kept.contains(i)) i,
    ].iterator;
    final start = [for (var p = 0; p < r.length; p++) r.fixed.contains(p) ? r.order[p] : (rest..moveNext()).current];
    if (_same(r.order, start)) return _unform(id);
    return _replace(r.checked(start), pushUndo: r)._unform(id);
  }

  /// A fresh jumble of one row, never back to the same spelling when the
  /// letters allow another. It can be undone like any other move.
  Board shuffle(int id, Random random) {
    final r = row(id);
    if (r == null || r.solved || r.isBlank) return this;
    // Only the letters a hint has not fixed are mixed.
    final open = [
      for (var p = 0; p < r.length; p++)
        if (!r.fixed.contains(p)) p,
    ];
    if (open.length < 2) return this;
    for (var attempt = 0; attempt < 20; attempt++) {
      final mixed = [for (final p in open) r.order[p]]..shuffle(random);
      final next = [...r.order];
      for (var k = 0; k < open.length; k++) {
        next[open[k]] = mixed[k];
      }
      if (next.map((i) => r.pool[i]).join() != r.letters) {
        return _replace(r.checked(next), pushUndo: r)._unform(id);
      }
    }
    return this;
  }

  /// The phone shaken: every unsolved word jumbled afresh. Solved words and
  /// the answer row stay exactly as they are.
  Board rescramble(Random random) {
    var board = this;
    for (final w in words) {
      if (!w.solved) board = board.shuffle(w.id, random);
    }
    return board;
  }

  /// Takes back the latest move, skipping any on a row solved since.
  Board undoLast() {
    final steps = [...undo];
    while (steps.isNotEmpty) {
      final step = steps.removeLast();
      final r = row(step.rowId);
      if (r == null || r.solved) continue;
      final restored = Board(
        words: words,
        finalRow: finalRow,
        follows: follows,
        formed: {...formed, step.rowId: step.formed},
        undo: steps,
      );
      return restored._replace(r.checked(step.order));
    }
    return Board(words: words, finalRow: finalRow, follows: follows, formed: formed);
  }

  /// One letter put right in row [id], for the Hint button: the square under
  /// the cursor, or the next one from there that is wrong (around to the
  /// start if need be). The right letter is taken out of its square and put
  /// in, the letters between sliding along (never a swap), and the square is
  /// fixed. The cursor moves on to the next square still wrong. Null when
  /// nothing can be placed: solved, the answer not here, or no right letter
  /// free to move.
  ({Board board, int tile, int square})? placeHint(int id) {
    final r = row(id);
    if (r == null || r.solved || r.answer.length != r.length) return null;
    final letters = r.letters, answer = r.answer;
    bool wrong(String spelled, int p) => !r.fixed.contains(p) && spelled[p] != answer[p];

    final cursor = r.nextOpen(min(formedIn(id), r.formable)).clamp(0, r.length);
    for (final square in [for (var i = cursor; i < r.length; i++) i, for (var i = 0; i < cursor; i++) i]) {
      if (!wrong(letters, square)) continue;
      // The right letter, from a square where it is not already right, and
      // the nearest such, so the fewest letters slide.
      final from =
          [
            for (var q = 0; q < r.length; q++)
              if (q != square && !r.fixed.contains(q) && letters[q] == answer[square]) q,
          ]..sort((a, b) {
            final byPlace = (letters[a] == answer[a] ? 1 : 0) - (letters[b] == answer[b] ? 1 : 0);
            return byPlace != 0 ? byPlace : (a - square).abs() - (b - square).abs();
          });
      if (from.isEmpty) continue;

      final order = r.order.movedAround(from.first, square, r.fixed);
      final placed = r.copyWith(fixed: {...r.fixed, square}).checked(order);
      final after = _replace(placed);
      // A hint is help asked for: Undo does not take it back, nor any move
      // on this row from before it.
      final board = Board(
        words: after.words,
        finalRow: after.finalRow,
        follows: follows,
        formed: after.formed,
        undo: [
          for (final s in after.undo)
            if (s.rowId != id) s,
        ],
      );
      final spelled = placed.letters;
      var next = r.length;
      for (final q in [for (var i = square + 1; i < r.length; i++) i, for (var i = 0; i < square; i++) i]) {
        if (!placed.fixed.contains(q) && spelled[q] != answer[q]) {
          next = q;
          break;
        }
      }
      return (board: board._withFormed(id, next), tile: r.order[from.first], square: square);
    }
    return null;
  }

  /// Shows a word's answer: solved, marked revealed, and locked.
  Board reveal(int id) {
    final r = row(id);
    if (r == null || r.solved) return this;
    final order = spellingOrder(r.pool, r.answer);
    if (order != null) return _replace(r.copyWith(order: order, solved: true, revealed: true));
    // The answer row before every word is in: shown as the answer itself.
    if (!r.isFinal) return this;
    return _replace(
      r.copyWith(pool: r.answer, order: List.generate(r.answer.length, (i) => i), solved: true, revealed: true),
    );
  }

  // ------------------------------------------------------------- internals

  /// Swaps in [updated], keeps the old order for undo when [pushUndo] is set,
  /// and refreshes the final row from the words' circles.
  Board _replace(RowState updated, {RowState? pushUndo}) {
    var steps = undo;
    if (pushUndo != null) {
      steps = [...steps, UndoStep(pushUndo.id, pushUndo.order, formedIn(pushUndo.id))];
    }
    // A solved row is locked, so its moves can no longer be taken back.
    if (updated.solved) steps = steps.where((s) => s.rowId != updated.id).toList();
    if (steps.length > maxUndo) steps = steps.sublist(steps.length - maxUndo);

    final nextWords = updated.isFinal ? words : [for (final w in words) w.id == updated.id ? updated : w];
    var nextFinal = updated.isFinal ? updated : finalRow;
    if (follows && !nextFinal.solved && !updated.isFinal) {
      nextFinal = nextFinal.copyWith(pool: circledLetters(nextWords));
      nextFinal = nextFinal.checked(nextFinal.order);
    }
    return Board(words: nextWords, finalRow: nextFinal, follows: follows, formed: formed, undo: steps);
  }

  Board _withFormed(int id, int count) {
    // The cursor never rests on a square a hint fixed.
    final at = row(id)?.nextOpen(max(0, count)) ?? max(0, count);
    return Board(words: words, finalRow: finalRow, follows: follows, formed: {...formed, id: at}, undo: undo);
  }

  Board _unform(int id) => formed.containsKey(id)
      ? Board(words: words, finalRow: finalRow, follows: follows, formed: Map.of(formed)..remove(id), undo: undo)
      : this;
}

// ------------------------------------------------------------- pure helpers

extension MovedList<T> on List<T> {
  /// This list with the item at [from] taken out and put back in at [to], the
  /// items between sliding along: A B C D E with C moved first is C A B D E.
  List<T> moved(int from, int to) {
    if (from < 0 || to < 0 || from >= length || to >= length || from == to) return this;
    final out = [...this];
    out.insert(to, out.removeAt(from));
    return out;
  }
}

extension MovedAround on List<int> {
  /// [moved], with the squares in [fixed] left where they are: the others
  /// slide around them. A move from or onto a fixed square does nothing.
  List<int> movedAround(int from, int to, Set<int> fixed) {
    if (fixed.isEmpty) return moved(from, to);
    if (fixed.contains(from) || fixed.contains(to)) return this;
    final open = [
      for (var p = 0; p < length; p++)
        if (!fixed.contains(p)) p,
    ];
    final tiles = [for (final p in open) this[p]].moved(open.indexOf(from), open.indexOf(to));
    final out = [...this];
    for (var k = 0; k < open.length; k++) {
      out[open[k]] = tiles[k];
    }
    return out;
  }
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The letters a row starts with: the printed scramble when it truly
/// rearranges [answer]; otherwise the answer rotated, so a misread scramble
/// never leaves the player with letters that cannot spell it, and no row
/// starts solved.
String startingLetters(String given, String answer) {
  // Only the hash is known: the printed letters are all there is.
  if (answer.isEmpty) return given.toUpperCase().replaceAll(RegExp('[^A-Z]'), '');
  final target = answer.toUpperCase().replaceAll(RegExp('[^A-Z]'), '');
  final printed = given.toUpperCase().replaceAll(RegExp('[^A-Z]'), '');
  String sorted(String s) => (s.split('')..sort()).join();
  if (printed.length == target.length && sorted(printed) == sorted(target) && printed != target) {
    return printed;
  }
  if (target.length < 2 || target.split('').toSet().length < 2) return target;
  var mixed = target;
  var shift = 1;
  while (mixed == target) {
    mixed = target.substring(shift) + target.substring(0, shift);
    shift++;
  }
  return mixed;
}

/// The circled letters, word 1 to the last, left to right — a space for each
/// circle of a word not solved yet. As on paper, a word's circled letters are
/// only copied down once it is right.
String circledLetters(List<RowState> words) => [
  for (final w in words)
    for (var i = 0; i < w.circles.length; i++)
      if (w.circles[i]) (w.solved && i < w.length ? w.letters[i] : ' '),
].join();

/// The order of [pool] that spells [text], each pool letter used once; null
/// when it cannot.
List<int>? spellingOrder(String pool, String text) {
  final free = List.generate(pool.length, (i) => i);
  final out = <int>[];
  for (final c in text.split('')) {
    final at = free.indexWhere((i) => pool[i] == c);
    if (at < 0) return null;
    out.add(free.removeAt(at));
  }
  return out.length == pool.length ? out : null;
}
