import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../data/puzzle_library.dart';
import '../../data/records_repository.dart';
import '../../game/board.dart';
import '../../game/game_controller.dart';
import '../feedback.dart';
import '../share_card.dart';
import '../theme.dart';
import '../widgets/celebration.dart';
import '../widgets/play_parts.dart';
import '../widgets/sheet_views.dart';
import '../widgets/tile_row.dart';

/// Playing one puzzle: the Words and Cartoon pages, the clue, the answer row
/// and the controls. Only the pages move when the page turns.
class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key, required this.onOpenLeaderboard});
  final VoidCallback onOpenLeaderboard;

  /// Whether a game is on screen, so nothing else lifts its screenshot block.
  static bool open = false;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> with WidgetsBindingObserver {
  late final GameController game = context.read<GameController>();
  late final GameFeedback feedback = context.read<GameFeedback>();
  late final ShakeDetector _shake = ShakeDetector(_onShake);
  final _pages = PageController();
  final _keys = FocusNode(debugLabel: 'board keys');

  /// The cartoon comes first; the jumbled words are one swipe to the right.
  static const _cartoonPage = 0, _wordsIndex = 1;
  int _page = _cartoonPage;

  /// The row last tapped or touched; hints and the underscore follow it.
  int? _focus;
  bool _congratulated = false;

  /// Every word is in and the answer row is waiting.
  bool _finalReady = false;

  /// Confetti over the board, once, the moment the puzzle is solved.
  bool _celebrate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // No screenshots or recordings of the board: the puzzle stays a puzzle.
    // Sharing a win goes through its own card, drawn without the answer.
    PlayScreen.open = true;
    unawaited(NoScreenshot.instance.screenshotOff().catchError((Object _) => false));
    game.onSound = feedback.play;
    game.onHintUnavailable = () {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('This needs a connection to BluJem. Try again in a moment.')));
    };
    game.onHintNeedsSignIn = () {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to use hints.')));
    };
    game.addListener(_onGame);
    // A run left part-way carries on, its clock running again.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) game.boardShown();
    });
    _congratulated = game.completed;
    _finalReady = _isFinalReady;
    _onGame();
  }

  @override
  void dispose() {
    PlayScreen.open = false;
    unawaited(NoScreenshot.instance.screenshotOn().catchError((Object _) => false));
    WidgetsBinding.instance.removeObserver(this);
    game.removeListener(_onGame);
    // Off the board, the clock holds and the run waits as it is.
    // Just after the screen is gone, so no other screen redraws mid-teardown.
    scheduleMicrotask(game.boardHidden);
    _shake.stop();
    _pages.dispose();
    _keys.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) game.onResumed();
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) game.onLeftApp();
  }

  /// Goes up with each shake, for the rows to jiggle.
  int _shuffleTick = 0;

  /// A shake: every unsolved word jumbled again — felt (a double buzz), seen
  /// (the words jiggle and their letters glide) and said (a short note).
  void _onShake() {
    if (!game.rescramble() || !mounted) return;
    unawaited(shuffleBuzz());
    setState(() => _shuffleTick++);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shuffle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Letters reshuffled', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          width: 220,
          duration: Duration(milliseconds: 1600),
        ),
      );
  }

  void _onGame() {
    if (game.started && !game.completed) {
      _shake.start();
    } else {
      _shake.stop();
    }
    if (!game.started) _congratulated = _celebrate = false;
    final ready = _isFinalReady;
    if (ready && !_finalReady) {
      // After the last word's own feedback, so the two do not run together.
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _isFinalReady) feedback.finalReady();
      });
    }
    _finalReady = ready;
    if (game.completed && !_congratulated) {
      _congratulated = true;
      if (mounted) setState(() => _celebrate = true);
      // The solved row and the confetti get a moment before the results.
      Future.delayed(const Duration(milliseconds: 1100), _showResults);
    }
  }

  bool get _isFinalReady => game.started && !game.completed && game.board.allWordsSolved;

  void _showResults() {
    if (!mounted) return;
    showCompletionSheet(
      context,
      game,
      streak: context.read<RecordsRepository>().stats.currentStreak,
      onLeaderboard: () {
        Navigator.of(context).maybePop();
        widget.onOpenLeaderboard();
      },
    );
  }

  void _goToPage(int page) =>
      _pages.animateToPage(page, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);

  void _onPageChanged(int page) {
    setState(() => _page = page);
    feedback.notePageTurn();
  }

  // ------------------------------------------------------------- keyboard

  /// Type to form, Backspace to step back, Tab to move rows, ⌘Z to undo.
  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent || !game.started || game.completed) return KeyEventResult.ignored;
    final target = game.hintTarget(_focus);
    if (target == null) return KeyEventResult.ignored;
    final row = game.board.row(target)!;
    // Typing a word: its letters are on the Words page.
    if (target != finalRowId && _page != _wordsIndex) _goToPage(_wordsIndex);
    final keys = HardwareKeyboard.instance;
    final key = event.logicalKey;

    if ((keys.isMetaPressed || keys.isControlPressed) && key == LogicalKeyboardKey.keyZ) {
      game.undo();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab || key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      final open = game.board.rows.where((r) => !r.solved).map((r) => r.id).toList();
      if (open.isEmpty) return KeyEventResult.handled;
      final step = keys.isShiftPressed || key == LogicalKeyboardKey.arrowUp ? -1 : 1;
      final at = open.indexOf(target);
      setState(() => _focus = open[(at + step) % open.length]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      final formed = game.board.formedIn(target);
      if (formed > 0) game.tapLetter(target, formed - 1);
      return KeyEventResult.handled;
    }
    final char = event.character?.toUpperCase();
    if (char != null && RegExp(r'^[A-Z]$').hasMatch(char)) {
      final from = game.board.formedIn(target);
      final letters = row.letters;
      for (var i = from; i < letters.length; i++) {
        if (letters[i] == char) {
          game.tapLetter(target, i);
          break;
        }
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ------------------------------------------------------------- building

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([game, feedback, context.read<PuzzleLibrary>()]),
      builder: (context, _) {
        final playing = game.started && !game.awaitingToday;
        return Scaffold(
          appBar: AppBar(
            // Only what a player glances at: the day, the clock, the menu.
            title: Text(
              game.awaitingToday ? dayLabel() : dayLabel(game.puzzle.publishDate),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            actions: [
              if (playing && game.showsMultiplier) ...[
                SpeedChip(seconds: game.pointsSeconds),
                const SizedBox(width: 6),
              ],
              if (playing) ClockChip(game: game),
              IconButton(
                tooltip: 'How to play',
                onPressed: () => showHowToPlay(context, pointsOn: game.scores.available && !game.playedBefore),
                icon: const Icon(Icons.help_outline_rounded),
              ),
              _MoreMenu(game: game, feedback: feedback, playing: playing),
            ],
          ),
          body: SafeArea(
            top: false,
            child: playing
                ? Stack(
                    children: [
                      _board(context),
                      if (_celebrate) const Positioned.fill(child: ConfettiBurst()),
                    ],
                  )
                : _beforeStart(context),
          ),
        );
      },
    );
  }

  Widget _beforeStart(BuildContext context) {
    final library = context.read<PuzzleLibrary>();
    final p = context.palette;
    final canStart = !game.awaitingToday;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (game.awaitingToday && !library.checked)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (game.awaitingToday)
                    NoticeCard(
                      icon: Icons.hourglass_top_rounded,
                      title: "Today's puzzle isn't up yet",
                      body: "It hasn't been published yet. We'll check every minute and switch to it as soon as it's here.",
                      action: TextButton.icon(
                        onPressed: library.syncing ? null : library.sync,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(library.syncing ? 'Checking…' : 'Check again'),
                      ),
                    )
                  else ...[
                    if (game.standingIn) ...[
                      NoticeCard(
                        icon: Icons.schedule_rounded,
                        title: "Today's puzzle isn't up yet",
                        body: game.playedBefore
                            ? 'You already finished ${library.standInDayName()} puzzle. You can play it again for fun — no points this time.'
                            : "Here's ${library.standInDayName()} puzzle to play while you wait. We'll switch to today's when it's ready.",
                      ),
                      const SizedBox(height: 16),
                    ],
                    StartCard(
                      game: game,
                      fromDay: game.isDaySlot && !game.standingIn ? null : longDate(game.puzzle.publishDate),
                      pointsOn: game.scores.available && !game.playedBefore,
                      streak: context.watch<RecordsRepository>().stats.currentStreak,
                      bestSeconds: context.watch<RecordsRepository>().stats.bestSeconds,
                    ),
                  ],
                  if (game.awaitingToday) ...[
                    const SizedBox(height: 16),
                    Text('While you wait', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Open an earlier puzzle from History.', style: TextStyle(color: p.inkSoft)),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (canStart)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: StartBar(game: game),
          ),
      ],
    );
  }

  Widget _board(BuildContext context) {
    final p = context.palette;
    final board = game.board;
    final puzzle = game.puzzle;
    final active = game.completed ? null : game.hintTarget(_focus);

    return Focus(
      focusNode: _keys,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            children: [
              if (game.alreadyScored)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Already scored — replays earn no new points.',
                    style: TextStyle(color: p.inkSoft, fontSize: 13),
                  ),
                ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: game.showResumedNotice
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: NoticeCard(
                          icon: Icons.play_circle_outline_rounded,
                          title: 'Timer resumed',
                          body: 'The clock paused while you were away and picked up exactly where it stopped.',
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: _PagerBar(
                  page: _page,
                  solved: [for (final w in board.words) w.solved],
                  nudge: !feedback.pagerLearned,
                  onPage: _goToPage,
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: _onPageChanged,
                  children: [
                    // The cartoon gets the whole page down to the answer row,
                    // as large as it fits without cropping; a pulsing arrow
                    // points to the words until they are all solved.
                    Stack(
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                            child: CartoonView(puzzle: puzzle),
                          ),
                        ),
                        if (!board.allWordsSolved)
                          Positioned(
                            right: 10,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: SwipeArrow(label: 'Swipe for words', onTap: () => _goToPage(_wordsIndex)),
                            ),
                          ),
                      ],
                    ),
                    _wordsPage(context, active),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.zero,
                child: _FinalCard(
                  ready: _finalReady,
                  active: active == finalRowId,
                  solved: board.finalRow.solved,
                  child: TileRow(
                    row: board.finalRow,
                    color: p.accent,
                    groups: puzzle.finalGroups,
                    formed: board.formedIn(finalRowId),
                    hintTile: game.lastHint?.rowId == finalRowId ? game.lastHint!.tile : null,
                    hintTick: game.lastHint?.rowId == finalRowId ? game.lastHint!.tick : 0,
                    enabled: !game.completed,
                    showCursor: active == finalRowId,
                    answerText: puzzle.finalShapeText,
                    lineBreaks: puzzle.finalLineBreaks,
                    maxTile: 44,
                    semanticLabel: board.finalRow.solved
                        ? 'Final answer, solved'
                        : 'Final answer${active == finalRowId ? ', active' : ''}',
                    onTap: (i) => _act(finalRowId, () => game.tapLetter(finalRowId, i)),
                    onDrag: (a, b) => _act(finalRowId, () => game.dragLetter(finalRowId, a, b)),
                    onMiss: () => _focusRow(finalRowId),
                    onFixed: _fixedLetter,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _ActionBar(game: game, target: active, onResults: _showResults, onHint: _hint),
            ],
          ),
        ),
      ),
    );
  }

  void _focusRow(int rowId) {
    if (_focus != rowId && game.board.row(rowId)?.solved == false) setState(() => _focus = rowId);
    _keys.requestFocus();
  }

  /// Hint: one right letter into the active word. The letters are on the
  /// Words page, so a word's hint turns back to it first.
  void _hint(int rowId) {
    if (rowId != finalRowId && _page != _wordsIndex) _goToPage(_wordsIndex);
    setState(() => _focus = rowId);
    unawaited(game.hintLetter(rowId));
  }

  /// A solved word's meaning, from the glossary bundled with the app.
  Future<void> _showMeaning(String word) async {
    final meaning = await game.hints.meaningOf(word);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) {
        final t = Theme.of(sheet).textTheme;
        final p = sheet.palette;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(word, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 2)),
                const SizedBox(height: 10),
                Text(
                  meaning ?? 'No meaning saved for this word yet.',
                  style: t.bodyLarge?.copyWith(color: meaning == null ? p.inkSoft : p.ink, height: 1.4),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// A letter a hint put right was touched: it stays, and a short note says why.
  void _fixedLetter() {
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('You already used a hint here, and this letter is now in its correct place.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _act(int rowId, VoidCallback action) {
    _focusRow(rowId);
    action();
  }

  Widget _wordsPage(BuildContext context, int? active) {
    final p = context.palette;
    final board = game.board;
    // The words are colour bands, edge to edge and touching, like the strips
    // of a printed Jumble. Every unsolved word stays at full strength and can
    // be played in any order; the one being played has the deeper colour.
    // Every word's squares are the size the longest word's need, so a
    // six-letter word does not get smaller letters than a five.
    final longest = board.words.fold<int>(0, (a, w) => max(a, w.length));
    // The clue sits under the words on this page only: the cartoon carries
    // its own caption, so its page gives the room to the picture.
    final words = LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < board.words.length; i++)
                  _WordRow(
                    number: i + 1,
                    row: board.words[i],
                    color: p.rowColor(i),
                    active: board.words[i].id == active,
                    sizeFor: longest,
                    shuffleTick: _shuffleTick,
                    formed: board.formedIn(board.words[i].id),
                    hintTile: game.lastHint?.rowId == board.words[i].id ? game.lastHint!.tile : null,
                    hintTick: game.lastHint?.rowId == board.words[i].id ? game.lastHint!.tick : 0,
                    enabled: !game.completed,
                    onTap: (x) => _act(board.words[i].id, () => game.tapLetter(board.words[i].id, x)),
                    onDrag: (a, b) => _act(board.words[i].id, () => game.dragLetter(board.words[i].id, a, b)),
                    onFocus: () => _focusRow(board.words[i].id),
                    onFixed: _fixedLetter,
                    onMeaning: () => _showMeaning(board.words[i].letters),
                  ),
              ],
            ),
          ),
        );
      },
    );
    return Column(
      children: [
        Expanded(child: words),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
          child: Text(
            game.puzzle.finalClue,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: clueStyle(p),
          ),
        ),
      ],
    );
  }
}

/// The final clue, set like a caption on the printed page.
TextStyle clueStyle(Palette p) => TextStyle(
  fontFamily: 'Georgia',
  fontFamilyFallback: const ['serif', 'Noto Serif'],
  fontSize: 17,
  height: 1.3,
  fontStyle: FontStyle.italic,
  fontWeight: FontWeight.w600,
  color: p.ink,
);

/// One word: unsolved and waiting, being played, or solved. All three look
/// playable or finished — never greyed out — so any word can be picked next.
class _WordRow extends StatefulWidget {
  const _WordRow({
    required this.number,
    required this.row,
    required this.color,
    required this.active,
    required this.sizeFor,
    required this.shuffleTick,
    required this.formed,
    required this.enabled,
    required this.onTap,
    required this.onDrag,
    required this.onFocus,
    this.hintTile,
    this.hintTick = 0,
    this.onFixed,
    this.onMeaning,
  });

  final VoidCallback? onFixed;

  /// The check of a solved word was tapped: show what the word means.
  final VoidCallback? onMeaning;
  final int? hintTile;
  final int hintTick;
  final int number;
  final RowState row;
  final Color color;
  final bool active;
  final int sizeFor;
  final int shuffleTick;
  final int formed;
  final bool enabled;
  final void Function(int index) onTap;
  final void Function(int from, int to) onDrag;
  final VoidCallback onFocus;

  @override
  State<_WordRow> createState() => _WordRowState();
}

class _WordRowState extends State<_WordRow> with SingleTickerProviderStateMixin {
  /// The little pop and sparkle when the word comes right.
  late final AnimationController _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void didUpdateWidget(_WordRow old) {
    super.didUpdateWidget(old);
    if (widget.row.solved && !old.row.solved && !reduceMotion(context)) _pop.forward(from: 0);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final solved = widget.row.solved;
    final active = widget.active && !solved;
    final state = solved ? 'solved' : (active ? 'active' : 'unsolved, available');
    // A full-width band, square-cornered: pastel while waiting, deeper while
    // being played, and the word's own colour once solved.
    final band = Color.alphaBlend(widget.color.withValues(alpha: active ? 0.5 : (solved ? 0.32 : 0.22)), p.paper);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onFocus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        color: band,
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
        child: AnimatedBuilder(
          animation: _pop,
          // The letters pop 1 → 1.04 → 1 when the word comes right; the band stays put.
          builder: (context, child) => Transform.scale(scale: 1 + sin(_pop.value * pi) * 0.04, child: child),
          // No printed number: the colour tells the words apart, and the
          // right edge only fills with a check once the word is right.
          child: Row(
            children: [
              const SizedBox(width: 36),
              Expanded(
                child: TileRow(
                  row: widget.row,
                  color: widget.color,
                  groups: [widget.row.length],
                  sizeFor: widget.sizeFor,
                  shuffleTick: widget.shuffleTick,
                  hintTile: widget.hintTile,
                  hintTick: widget.hintTick,
                  onFixed: widget.onFixed,
                  formed: widget.formed,
                  enabled: widget.enabled,
                  showCursor: active,
                  onTap: widget.onTap,
                  semanticLabel: 'Word ${widget.number}, $state',
                  onDrag: widget.onDrag,
                  onMiss: widget.onFocus,
                ),
              ),
              const SizedBox(width: 8),
              _SolvedMark(solved: solved, pop: _pop, word: widget.row.letters, onTap: widget.onMeaning),
            ],
          ),
        ),
      ),
    );
  }
}

/// The check that pops in when a word comes right; empty space before that.
class _SolvedMark extends StatelessWidget {
  const _SolvedMark({required this.solved, required this.pop, required this.word, this.onTap});
  final bool solved;
  final Animation<double> pop;
  final String word;

  /// Tapped once solved: the word's meaning.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final mark = SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // A few sparks thrown off the check as the word comes right.
          AnimatedBuilder(
            animation: pop,
            builder: (_, _) => pop.value == 0 || pop.value == 1
                ? const SizedBox.shrink()
                : CustomPaint(size: const Size(28, 28), painter: _SparkPainter(pop.value, p.accent)),
          ),
          AnimatedScale(
            scale: solved ? 1 : 0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: p.success, shape: BoxShape.circle),
              child: Icon(Icons.check_rounded, size: 18, color: p.paper),
            ),
          ),
        ],
      ),
    );
    if (!solved || onTap == null) return mark;
    // A finger-sized target around the small check.
    return Semantics(
      button: true,
      label: 'What $word means',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        child: Padding(padding: const EdgeInsets.all(8), child: mark),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final paint = Paint()..color = color.withValues(alpha: 1 - t);
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4;
      final r = 14 + 12 * Curves.easeOut.transform(t);
      canvas.drawCircle(c + Offset(cos(a), sin(a)) * r, 2.6 * (1 - t) + 0.8, paint);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.t != t;
}

/// The answer row's frame: it glows gently when every word is in, and says
/// so, without giving anything away.
class _FinalCard extends StatefulWidget {
  const _FinalCard({required this.ready, required this.active, required this.solved, required this.child});
  final bool ready;
  final bool active;
  final bool solved;
  final Widget child;

  @override
  State<_FinalCard> createState() => _FinalCardState();
}

class _FinalCardState extends State<_FinalCard> with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.ready) WidgetsBinding.instance.addPostFrameCallback((_) => _pulse());
  }

  @override
  void didUpdateWidget(_FinalCard old) {
    super.didUpdateWidget(old);
    if (widget.ready && !old.ready) _pulse();
  }

  /// Three slow breaths, then still.
  Future<void> _pulse() async {
    if (reduceMotion(context)) return;
    for (var i = 0; i < 3 && mounted; i++) {
      await _glow.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          child: widget.ready
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 16, color: p.accent),
                        const SizedBox(width: 6),
                        Text(
                          'Final answer ready!',
                          style: TextStyle(color: p.paper, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        // A full-width band like the words', in the answer's yellow. When it is
        // ready its letters breathe a little bigger three times.
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          color: Color.alphaBlend(
            (widget.solved ? p.success : p.accent).withValues(alpha: widget.active || widget.ready ? 0.42 : 0.24),
            p.paper,
          ),
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
          child: AnimatedBuilder(
            animation: _glow,
            builder: (context, child) => Transform.scale(scale: 1 + 0.04 * sin(_glow.value * pi), child: child),
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

/// Word progress on one side, the way to the other page on the other.
class _PagerBar extends StatelessWidget {
  const _PagerBar({required this.page, required this.solved, required this.nudge, required this.onPage});
  final int page;
  final List<bool> solved;
  final bool nudge;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final progress = WordProgress(solved: solved);
    return SizedBox(
      height: 34,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: page == 0
            ? Row(
                key: const ValueKey('cartoon'),
                children: [
                  progress,
                  const Spacer(),
                  PagerHint(label: 'See Words', forward: true, nudge: nudge, onTap: () => onPage(1)),
                ],
              )
            : Row(
                key: const ValueKey('words'),
                children: [
                  PagerHint(label: 'See Cartoon', forward: false, nudge: nudge, onTap: () => onPage(0)),
                  const Spacer(),
                  progress,
                ],
              ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.game, required this.target, required this.onResults, required this.onHint});
  final GameController game;
  final int? target;
  final VoidCallback onResults;
  final void Function(int rowId) onHint;

  @override
  Widget build(BuildContext context) {
    if (game.completed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: FilledButton.icon(
          onPressed: onResults,
          icon: const Icon(Icons.emoji_events_rounded),
          label: const Text('See results'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
      );
    }
    final t = target;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _GameButton(icon: Icons.undo_rounded, label: 'Undo', onPressed: game.board.canUndo ? game.undo : null),
          _GameButton(
            icon: Icons.lightbulb_rounded,
            label: 'Hint',
            // Its own buzz and chime: no button tick on top.
            quiet: true,
            onPressed: t == null || game.hinting ? null : () => onHint(t),
          ),
          _GameButton(
            icon: Icons.shuffle_rounded,
            label: 'Mix',
            onPressed: t == null ? null : () => game.shuffleRow(t),
          ),
          _GameButton(
            icon: Icons.restart_alt_rounded,
            label: 'Reset',
            onPressed: t == null ? null : () => game.resetRow(t),
          ),
        ],
      ),
    );
  }
}

/// A chunky rounded key with its label underneath, that sinks when pressed.
class _GameButton extends StatefulWidget {
  const _GameButton({required this.icon, required this.label, required this.onPressed, this.quiet = false});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// No tick of its own: the action brings its own feedback.
  final bool quiet;

  @override
  State<_GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<_GameButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final on = widget.onPressed != null;
    final face = p.card;
    final edge = p.rule;
    final ink = on ? p.ink : p.inkFaint;
    return Semantics(
      button: true,
      enabled: on,
      label: widget.label,
      child: GestureDetector(
        onTapDown: on ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: on
            ? (_) {
                setState(() => _down = false);
                if (!widget.quiet) HapticFeedback.selectionClick();
                widget.onPressed!();
              }
            : null,
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                width: 60,
                height: 46,
                margin: EdgeInsets.only(top: _down ? 3 : 0, bottom: _down ? 0 : 3),
                decoration: BoxDecoration(
                  color: on ? face : p.sunken,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: on ? edge : p.rule, width: 1.5),
                  boxShadow: on && !_down ? [BoxShadow(color: edge, offset: const Offset(0, 3))] : null,
                ),
                child: Icon(widget.icon, color: ink, size: 24),
              ),
              const SizedBox(height: 3),
              Text(
                widget.label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.game, required this.feedback, required this.playing});
  final GameController game;
  final GameFeedback feedback;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: const Icon(Icons.more_horiz_rounded),
      onSelected: (v) async {
        switch (v) {
          case 'sound':
            feedback.toggleMuted();
          case 'sheet':
            showWholeSheet(context, game.puzzle);
          case 'reset':
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Reset puzzle?'),
                content: const Text('Every letter goes back as printed and the clock starts over.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reset')),
                ],
              ),
            );
            if (ok == true) game.resetPuzzle();
          case 'answers':
            if (await confirmShowAnswers(context)) unawaited(game.showAnswers());
          case 'share':
            await shareWin(context, game);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'sound',
          child: ListTile(
            leading: Icon(feedback.muted ? Icons.volume_up_rounded : Icons.volume_off_rounded),
            title: Text(feedback.muted ? 'Turn sound on' : 'Turn sound off'),
          ),
        ),
        if (playing)
          const PopupMenuItem(
            value: 'sheet',
            child: ListTile(leading: Icon(Icons.description_outlined), title: Text('View printed sheet')),
          ),
        if (playing && !game.completed && (game.earnsHalf || game.playedBefore))
          const PopupMenuItem(
            value: 'answers',
            child: ListTile(leading: Icon(Icons.visibility_outlined), title: Text('Show answers…')),
          ),
        if (canShareWin(game))
          const PopupMenuItem(
            value: 'share',
            child: ListTile(leading: Icon(Icons.ios_share_rounded), title: Text('Share your win')),
          ),
        if (playing)
          const PopupMenuItem(
            value: 'reset',
            child: ListTile(leading: Icon(Icons.restart_alt_rounded), title: Text('Reset puzzle…')),
          ),
      ],
    );
  }
}
