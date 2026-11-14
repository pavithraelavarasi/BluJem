import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/slots.dart';
import '../data/hint_service.dart';
import '../data/puzzle_library.dart';
import '../data/records_repository.dart';
import '../data/score_repository.dart';
import '../models/puzzle.dart';
import '../models/records.dart';
import 'board.dart';

enum GameSound { key, solved, complete, start, shuffle, timeout }

enum RunStatus { notStarted, inProgress, completed }

/// The hints shown so far for one row.
class RowHints {
  const RowHints({this.texts = const [], this.loading = false, this.source});
  final List<String> texts;
  final bool loading;
  final HintSource? source;

  int get shown => texts.length;
  bool get allShown => shown >= HintService.levels;
}

/// One run of one puzzle: the board, both clocks, hints and the finish.
///
/// The rules of moving letters live in [Board]; this adds what a run needs
/// around them — time, points, hints, sound — and the choice of which sheet
/// is on the table.
class GameController extends ChangeNotifier {
  GameController({
    required this.library,
    required this.records,
    required this.scores,
    required this.hints,
    DateTime Function()? clock,
    Random? random,
  }) : _clock = clock ?? DateTime.now,
       _random = random ?? Random() {
    library.addListener(_onLibraryChanged);
    _open(library.dayPuzzle);
  }

  final PuzzleLibrary library;
  final RecordsRepository records;
  final ScoreRepository scores;
  final HintService hints;
  final DateTime Function() _clock;
  final Random _random;

  /// Called for each sound worth playing.
  void Function(GameSound sound)? onSound;

  /// Called when a hint needs the answers and the server could not be reached.
  void Function()? onHintUnavailable;

  late Puzzle puzzle;
  late Board board;

  bool started = false;
  bool paused = false;
  bool timedOut = false;
  bool completed = false;

  /// Shown for a moment on return, so the held clock is not a silent trick.
  bool showResumedNotice = false;
  int remainingSeconds = 0;
  int? _expiresAt;
  int? elapsedAtCompletion;
  int hintsUsed = 0;
  Map<int, RowHints> rowHints = const {};

  /// When the server's points clock started, by this device's clock; null when
  /// the run earns no points. Unlike the countdown it never pauses.
  int? _pointsOrigin;
  int pointsSeconds = 0;
  bool alreadyScored = false;
  bool scoring = false;
  PuzzleScore? score;

  /// This player finished this sheet before: a replay earns no points.
  bool playedBefore = false;

  /// This puzzle's earlier solve, kept on the phone, for sharing it later.
  Completion? get pastWin => records.runOf(puzzle.id);

  /// The player asked to see the solution: not a solve, so it neither counts
  /// as finished nor keeps a streak going.
  bool answersShown = false;

  Timer? _ticker;
  Timer? _waitingCheck;
  Timer? _noticeTimer;
  String? _account;

  // ------------------------------------------------------------- reading

  int get _now => _clock().millisecondsSinceEpoch;

  RunStatus get status => completed
      ? RunStatus.completed
      : started
      ? RunStatus.inProgress
      : RunStatus.notStarted;

  /// Today has nothing published at all; the sheet shown is only a sample.
  bool get awaitingToday => isDaySlot && library.dayKind == DayKind.awaiting;

  /// An earlier sheet is on the board in place of today's.
  bool get standingIn => isDaySlot && library.dayKind == DayKind.standIn;

  /// The day's slot is what is on the board, not a sheet from History.
  bool get isDaySlot => puzzle.id == library.dayPuzzle.id;

  bool get practiceMode => timedOut && !completed;

  bool get showsMultiplier => started && _pointsOrigin != null && !alreadyScored && !completed;

  int get multiplier => Multipliers.at(pointsSeconds);

  RowHints hintsFor(int rowId) => rowHints[rowId] ?? const RowHints();

  /// The row the hint button helps with: [focus] while unsolved, else the
  /// first open word, else the answer row.
  int? hintTarget(int? focus) {
    if (focus != null && board.row(focus)?.solved == false) return focus;
    for (final w in board.words) {
      if (!w.solved) return w.id;
    }
    return board.finalRow.solved ? null : finalRowId;
  }

  // ------------------------------------------------------------- choosing a sheet

  /// The day's sheet, unless it is already the one in play.
  void openToday() {
    _followsDay = true;
    _openIfNew(library.dayPuzzle);
  }

  /// A sheet picked from History or the calendar.
  void openPuzzle(Puzzle p) {
    _followsDay = p.id == library.dayPuzzle.id;
    _openIfNew(p);
  }

  void _openIfNew(Puzzle p) {
    if (p.id == puzzle.id) return;
    _open(p);
    notifyListeners();
  }

  /// A new account: today's sheet untouched, and their own record.
  Future<void> onAccountChanged(String? accountId) async {
    if (accountId == _account) return;
    _account = accountId;
    _followsDay = true;
    _open(library.dayPuzzle);
    notifyListeners();
    await records.switchAccount(accountId);
    playedBefore = records.finished(puzzle.id);
    notifyListeners();
    if (accountId != null) unawaited(library.sync());
  }

  void _open(Puzzle p) {
    _ticker?.cancel();
    puzzle = p;
    board = Board.start(p);
    started = paused = timedOut = completed = showResumedNotice = scoring = alreadyScored = false;
    remainingSeconds = p.timeLimitSeconds;
    _expiresAt = _pointsOrigin = elapsedAtCompletion = null;
    pointsSeconds = hintsUsed = 0;
    rowHints = const {};
    score = null;
    _startCall = null;
    answersShown = false;
    playedBefore = records.finished(p.id);
    _scheduleWaitingCheck();
  }

  /// Whether the board shows the day's slot rather than a sheet picked from
  /// History, so a newer day's sheet should replace it when one arrives.
  bool _followsDay = true;

  /// A newly published sheet for today replaces the day's slot, unless a run
  /// is underway — nobody loses progress to a download.
  void _onLibraryChanged() {
    final day = library.dayPuzzle;
    if (_followsDay && !started && !completed && day.id != puzzle.id) _open(day);
    _scheduleWaitingCheck();
    notifyListeners();
  }

  /// While a slot of today's has opened and its puzzle isn't here, look
  /// again every minute.
  void _scheduleWaitingCheck() {
    _waitingCheck?.cancel();
    if (!library.missingOpenedSlot || _account == null) return;
    _waitingCheck = Timer.periodic(const Duration(seconds: 60), (_) => library.sync());
  }

  // ------------------------------------------------------------- clocks

  void start() => _start(restart: false);

  /// The server's start of this run, which [showAnswers] waits for: the
  /// answers are given to a run the server knows about.
  Future<ScoreStart?>? _startCall;

  /// A puzzle from an earlier day: solved now, it earns half points.
  bool get earnsHalf => puzzle.publishDate.compareTo(indiaDate(_clock())) < 0;

  /// Every word and the answer filled in, for a player who wants to see the
  /// solution. The run ends with nothing earned.
  Future<void> showAnswers() async {
    if (completed || awaitingToday) return;
    if (!started) _start(restart: false);
    await _startCall;
    if (!await loadAnswers()) {
      onHintUnavailable?.call();
      return;
    }
    var next = board;
    for (final w in board.words) {
      next = next.reveal(w.id);
    }
    next = next.reveal(finalRowId);
    hintsUsed++;
    answersShown = true;
    _play(next, revealedFinal: true);
  }

  void _start({required bool restart}) {
    if (started || awaitingToday) return;
    final id = puzzle.id;
    final sentAt = _now;
    // The server times the run for points from its own clock; the strip counts
    // from when the call left, so it drops a tier early rather than late.
    _startCall = scores.start(id, restart: restart);
    _startCall!.then((clock) {
      if (clock == null || puzzle.id != id || !started) return;
      _pointsOrigin = sentAt - clock.elapsedSeconds * 1000;
      pointsSeconds = clock.elapsedSeconds;
      alreadyScored = clock.alreadyScored;
      notifyListeners();
    });
    started = true;
    onSound?.call(GameSound.start);
    _expiresAt = _now + puzzle.timeLimitSeconds * 1000;
    remainingSeconds = puzzle.timeLimitSeconds;
    _startTicker();
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => tick());
  }

  /// Recomputes both clocks from timestamps; nothing is decremented in place,
  /// so it is safe to call at any moment.
  @visibleForTesting
  void tick() {
    final expires = _expiresAt;
    if (!started || completed || timedOut || paused || expires == null) {
      _ticker?.cancel();
      return;
    }
    var changed = false;
    if (_pointsOrigin != null) {
      final s = max(0, (_now - _pointsOrigin!) ~/ 1000);
      if (s != pointsSeconds) {
        pointsSeconds = s;
        changed = true;
      }
    }
    final left = expires - _now;
    if (left <= 0) {
      // Time's up: the clock stops for good and play goes on, unscored by time.
      remainingSeconds = 0;
      timedOut = true;
      onSound?.call(GameSound.timeout);
      _ticker?.cancel();
      changed = true;
    } else {
      final s = (left + 999) ~/ 1000;
      if (s != remainingSeconds) {
        remainingSeconds = s;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// The player left the app: the countdown holds until they return.
  void onLeftApp() {
    if (!started || completed || timedOut || paused) return;
    tick();
    _ticker?.cancel();
    paused = true;
    notifyListeners();
  }

  /// Back: the expiry is rebuilt from what was left, so time away costs nothing.
  void onResumed() {
    if (!started || completed || timedOut) return;
    if (paused) {
      paused = false;
      showResumedNotice = true;
      _expiresAt = _now + remainingSeconds * 1000;
      _noticeTimer?.cancel();
      _noticeTimer = Timer(const Duration(seconds: 5), () {
        showResumedNotice = false;
        notifyListeners();
      });
    }
    tick();
    _startTicker();
    notifyListeners();
  }

  /// How long the run was actually played: the limit less what is left.
  int get _elapsed => started ? max(0, puzzle.timeLimitSeconds - remainingSeconds) : 0;

  // ------------------------------------------------------------- playing

  void tapLetter(int rowId, int index) => _play(board.form(rowId, index), sound: true);

  void dragLetter(int rowId, int from, int to) => _play(board.drag(rowId, from, to), sound: true);

  void undo() => _play(board.undoLast());

  void resetRow(int rowId) => _play(board.reset(rowId));

  void shuffleRow(int rowId) {
    final before = board;
    _play(board.shuffle(rowId, _random));
    if (!identical(before, board)) onSound?.call(GameSound.shuffle);
  }

  /// The phone shaken: every unsolved word jumbled again; the timer, hints,
  /// solved words and answer row are untouched. True when anything moved.
  bool rescramble() {
    final before = board;
    _play(board.rescramble(_random));
    final moved = !identical(before, board);
    if (moved) onSound?.call(GameSound.shuffle);
    return moved;
  }

  void revealRow(int rowId) {
    if (!started || completed) return;
    if (puzzle.answersHidden) {
      final id = puzzle.id;
      unawaited(
        loadAnswers().then((ok) {
          if (ok && puzzle.id == id && !puzzle.answersHidden) revealRow(rowId);
        }),
      );
      return;
    }
    final next = board.reveal(rowId);
    if (identical(next, board)) return;
    hintsUsed++;
    _play(next, revealedFinal: rowId == finalRowId);
  }

  void _play(Board next, {bool sound = false, bool revealedFinal = false}) {
    if (!started || completed || identical(next, board)) return;
    final solvedBefore = board.solvedCount + (board.finalRow.solved ? 1 : 0);
    board = next;
    final solvedNow = board.solvedCount + (board.finalRow.solved ? 1 : 0);
    if (board.finalRow.solved) {
      _finish(revealed: revealedFinal);
    } else if (solvedNow > solvedBefore) {
      onSound?.call(GameSound.solved);
    } else if (sound) {
      onSound?.call(GameSound.key);
    }
    notifyListeners();
  }

  /// Fetches the answers the server held back, into the puzzle and the
  /// board alike. True when they are here.
  Future<bool> loadAnswers() async {
    if (!puzzle.answersHidden) return true;
    final id = puzzle.id;
    final answers = await scores.answers(id);
    if (answers == null || puzzle.id != id) return false;
    puzzle = puzzle.withAnswers(answers.words, answers.finalAnswer, answers.explanation);
    board = board.withAnswers(puzzle);
    notifyListeners();
    return true;
  }

  void _finish({required bool revealed}) {
    completed = true;
    elapsedAtCompletion = _elapsed;
    _ticker?.cancel();
    onSound?.call(GameSound.complete);

    final run = Completion(
      puzzleId: puzzle.id,
      sheetDate: puzzle.sheetDate,
      finalAnswer: puzzle.finalFrom(board.finalRow.letters),
      seconds: elapsedAtCompletion!,
      hintsUsed: hintsUsed,
      completedAt: _now,
      timed: !timedOut,
    );
    final wasReplay = playedBefore;
    if (!answersShown) unawaited(records.record(run));
    // Solved by hash: the server's own words (and why it is funny) now.
    if (puzzle.answersHidden) unawaited(loadAnswers());

    // A replay earns nothing, so it is never sent to be scored.
    if (wasReplay || !scores.available) return;
    scoring = true;
    final id = puzzle.id;
    scores
        .submit(
          id,
          [for (final w in board.words) PlayedWord(w.letters, hintsUsed: hintsFor(w.id).shown, revealed: w.revealed)],
          board.finalRow.letters,
          finalRevealed: revealed,
        )
        .then((result) {
          if (puzzle.id != id) return;
          score = result;
          scoring = false;
          notifyListeners();
        });
  }

  // ------------------------------------------------------------- hints

  /// The next hint for [rowId], fetched without holding up the board.
  Future<void> requestHint(int rowId) async {
    final row = board.row(rowId);
    final current = hintsFor(rowId);
    if (row == null || row.solved || current.allShown || current.loading) return;
    final id = puzzle.id;
    _setHints(rowId, RowHints(texts: current.texts, loading: true, source: current.source));

    final level = current.shown + 1;
    // A hint is built from the answer, which the server sends once asked.
    if (!await loadAnswers()) {
      if (puzzle.id != id) return;
      _setHints(rowId, RowHints(texts: current.texts, source: current.source));
      onHintUnavailable?.call();
      return;
    }
    final Hint hint;
    if (rowId == finalRowId) {
      hint = await hints.finalHint(puzzle, level, current.texts, board.bonusLetters.replaceAll('?', ''));
    } else {
      hint = await hints.wordHint(puzzle, puzzle.words.firstWhere((w) => w.id == rowId), level, current.texts);
    }
    if (puzzle.id != id) return;
    hintsUsed++;
    _setHints(rowId, RowHints(texts: [...current.texts, hint.text], source: hint.source));
  }

  void _setHints(int rowId, RowHints value) {
    rowHints = {...rowHints, rowId: value};
    notifyListeners();
  }

  // ------------------------------------------------------------- whole run

  /// Every letter back as printed, and the clock waiting for Start again.
  void resetPuzzle() {
    final p = puzzle;
    _open(p);
    notifyListeners();
  }

  /// After time ran out: a clean sheet with both clocks running from now.
  void restartPuzzle() {
    resetPuzzle();
    _start(restart: true);
  }

  @override
  void dispose() {
    library.removeListener(_onLibraryChanged);
    _ticker?.cancel();
    _waitingCheck?.cancel();
    _noticeTimer?.cancel();
    super.dispose();
  }
}
