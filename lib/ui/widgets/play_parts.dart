import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../game/board.dart';
import '../../game/game_controller.dart';
import '../../models/records.dart';
import '../share_card.dart';
import '../theme.dart';
import 'share_win_button.dart';
import 'sheet_views.dart';
import 'tile_row.dart';

/// The countdown, or "Time's up" with a way to start over.
class ClockChip extends StatelessWidget {
  const ClockChip({super.key, required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (game.practiceMode) {
      return ActionChip(
        avatar: Icon(Icons.replay_rounded, size: 18, color: p.warning),
        label: Text(
          "Time's up",
          style: TextStyle(color: p.warning, fontWeight: FontWeight.w600),
        ),
        tooltip: 'Start over with a fresh clock',
        side: BorderSide(color: p.warning.withValues(alpha: 0.4)),
        backgroundColor: p.card,
        onPressed: game.restartPuzzle,
      );
    }
    final low = game.remainingSeconds <= 30 && !game.completed;
    final seconds = game.completed ? game.elapsedAtCompletion ?? 0 : game.remainingSeconds;
    return Semantics(
      label: game.completed
          ? 'Finished in ${clock(seconds)}'
          : '${clock(seconds)} left${game.paused ? ', paused' : ''}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: low ? p.warning.withValues(alpha: 0.12) : p.sunken,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(game.paused ? Icons.pause_rounded : Icons.timer_outlined, size: 18, color: low ? p.warning : p.ink),
            const SizedBox(width: 4),
            Text(
              clock(seconds),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: low ? p.warning : p.ink,
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The multiplier a finish right now would earn, and how long it lasts.
class SpeedChip extends StatelessWidget {
  const SpeedChip({super.key, required this.seconds});
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final x = Multipliers.at(seconds);
    final left = Multipliers.secondsLeftAt(seconds);
    return Tooltip(
      message: left == null ? 'Speed bonus: 1x' : '${x}x for ${clock(left)} more',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: x > 1 ? p.accent : p.sunken, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFF1C1B19)),
            Text(
              '${x}x',
              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1C1B19)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A note above the board: a title in the accent and a line of body text.
class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key, required this.icon, required this.title, required this.body, this.action});
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: p.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(body, style: TextStyle(color: p.inkSoft, height: 1.35)),
                if (action != null) Padding(padding: const EdgeInsets.only(top: 8), child: action),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Before Start: the cartoon kept out of focus and the time allowed. How to
/// play is behind the help button ([showHowToPlay]); the Start button is
/// [StartBar], pinned below, always in view.
class StartCard extends StatelessWidget {
  const StartCard({super.key, required this.game, required this.fromDay, required this.pointsOn});
  final GameController game;

  /// The sheet's day when it is not today's, for the time line.
  final String? fromDay;
  final bool pointsOn;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final puzzle = game.puzzle;
    final minutes = puzzle.timeLimitSeconds ~/ 60;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 150,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Image(image: sheetProvider(puzzle.image), fit: BoxFit.cover),
                ),
                Container(color: p.card.withValues(alpha: 0.35)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(game.playedBefore ? 'Play it again?' : 'Ready?', style: t.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  fromDay == null
                      ? "You get $minutes minutes for today's ${puzzle.difficulty.toLowerCase()} puzzle. "
                            'The clock starts when you tap below.'
                      : 'You get $minutes minutes for the puzzle from $fromDay. The clock starts when you tap below.',
                  style: TextStyle(color: p.inkSoft, height: 1.4),
                ),
                if (pointsOn) ...[
                  if (game.earnsHalf) ...[
                    const SizedBox(height: 8),
                    const _Rule(
                      icon: Icons.history_rounded,
                      text: 'This puzzle is from an earlier day, so it earns half points. Full points are for solving on the day it comes out.',
                    ),
                  ],
                ],
                if (canShareWin(game)) ...[const SizedBox(height: 12), ShareWinButton(game: game)],
                if (game.earnsHalf || game.playedBefore) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () async {
                      if (await confirmShowAnswers(context)) unawaited(game.showAnswers());
                    },
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Just show me the answers'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// How to play, with the points rule, in a sheet: opened from the help
/// button at the top of the game screen.
Future<void> showHowToPlay(BuildContext context, {required bool pointsOn}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (sheet) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.85),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How to play', style: Theme.of(sheet).textTheme.headlineSmall),
            const SizedBox(height: 16),
            const HowToPlay(),
            if (pointsOn) ...[
              const SizedBox(height: 16),
              const _Rule(
                icon: Icons.bolt_rounded,
                text: 'Finish fast for more points: 5x inside a minute, then 4x, 3x and 2x by 1:30, 2:00 and 3:00.',
              ),
            ],
            const SizedBox(height: 12),
            const _Rule(
              icon: Icons.pause_circle_outline_rounded,
              text: 'Leave the app and the countdown waits for you.',
            ),
          ],
        ),
      ),
    ),
  ),
);

/// The game's rules as numbered steps.
class HowToPlay extends StatelessWidget {
  const HowToPlay({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = [
      'Unscramble each word. Tap its letters in order: R A J A → tap A, J, A, R → A J A R. '
          'Or drag a letter to where it goes. A word fills with colour once it is right.',
      'Tap a formed letter to go back to it. '
          '${Theme.of(context).platform == TargetPlatform.macOS ? 'On a keyboard, type letters and press Backspace to undo.' : 'Shake the phone to mix the unsolved letters again.'}',
      'The circled letters drop into the answer row at the bottom.',
      'Swipe to the cartoon, read the riddle, and arrange the circled letters into the answer.',
      'Stuck? A hint fills in a word, but costs points. The faster you finish, the more you score.',
    ];
    return Column(
      children: [
        for (final (i, step) in steps.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          _Step(number: i + 1, text: step),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
          child: Text(
            '$number',
            style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1C1B19)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: TextStyle(color: p.ink, height: 1.35)),
        ),
      ],
    );
  }
}

/// The one thing to do before a puzzle: Start, pinned under the rules so it
/// is always in view.
class StartBar extends StatelessWidget {
  const StartBar({super.key, required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.paper,
        border: Border(top: BorderSide(color: p.rule)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: FilledButton.icon(
          onPressed: game.start,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(game.playedBefore ? 'Play Again (No Points)' : 'Start Puzzle'),
          // The game's gold, so it stands out as the one thing to do.
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(60),
            backgroundColor: p.accent,
            foregroundColor: const Color(0xFF1C1B19),
            elevation: 4,
            shadowColor: p.accent,
            textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

/// Asks before the solution is shown: doing so ends the run with no points.
Future<bool> confirmShowAnswers(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Show the answers?'),
        content: const Text('Every word and the final answer are filled in. This puzzle then earns no points.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep playing')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Show answers')),
        ],
      ),
    ) ==
    true;

class _Rule extends StatelessWidget {
  const _Rule({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: p.sunken, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: p.ink),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: TextStyle(color: p.ink, height: 1.35)),
        ),
      ],
    );
  }
}

/// The hints so far for one row, the next on request, and the answer for a
/// player who would rather see it. Follows the run as hints arrive.
Future<void> showHintSheet(BuildContext context, GameController game, int rowId) {
  if (game.hintsFor(rowId).shown == 0) game.requestHint(rowId);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final p = context.palette;
        final row = game.board.row(rowId);
        final h = game.hintsFor(rowId);
        final title = rowId == finalRowId
            ? 'Final answer'
            : 'Word ${game.board.words.indexWhere((w) => w.id == rowId) + 1}';
        if (row == null || row.solved) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).maybePop();
          });
        }
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_rounded, color: p.accent),
                    const SizedBox(width: 8),
                    Text('Hint · $title', style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    Text('${h.shown}/3', style: TextStyle(color: p.inkFaint)),
                  ],
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < h.texts.length; i++)
                  if (h.texts[i].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: p.sunken, borderRadius: BorderRadius.circular(14)),
                        child: Text('${i + 1}. ${h.texts[i]}', style: const TextStyle(fontSize: 16, height: 1.4)),
                      ),
                    ),
                if (h.loading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 10),
                        Text('Thinking of a hint…', style: TextStyle(color: p.inkSoft)),
                      ],
                    ),
                  ),
                if (h.source == HintSource.offline && !h.loading)
                  Text('Offline hint, from the dictionary.', style: TextStyle(color: p.inkFaint, fontSize: 12)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: h.allShown
                          ? FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: p.warning),
                              onPressed: () {
                                game.revealRow(rowId);
                                Navigator.pop(context);
                              },
                              child: const Text('Show answer'),
                            )
                          : FilledButton(
                              onPressed: h.loading ? null : () => game.requestHint(rowId),
                              child: const Text('Another hint'),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// The finish: the answer, why it is funny, time, hints and points.
Future<void> showCompletionSheet(
  BuildContext context,
  GameController game, {
  required int streak,
  required VoidCallback onLeaderboard,
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (context) => ListenableBuilder(
    listenable: game,
    builder: (context, _) => _CompletionBody(game: game, streak: streak, onLeaderboard: onLeaderboard),
  ),
);

class _CompletionBody extends StatelessWidget {
  const _CompletionBody({required this.game, required this.streak, required this.onLeaderboard});
  final GameController game;
  final int streak;
  final VoidCallback onLeaderboard;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final puzzle = game.puzzle;
    final score = game.score;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              builder: (_, s, child) => Transform.scale(scale: s, child: child),
              child: Icon(
                game.board.finalRow.revealed ? Icons.visibility_rounded : Icons.emoji_events_rounded,
                size: 56,
                color: p.accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              game.board.finalRow.revealed ? 'Here it is' : 'Puzzle solved!',
              textAlign: TextAlign.center,
              style: t.headlineSmall,
            ),
            const SizedBox(height: 16),
            IgnorePointer(
              child: TileRow(
                row: game.board.finalRow,
                color: p.accent,
                groups: puzzle.finalGroups,
                formed: 0,
                enabled: false,
                showCursor: false,
                onTap: (_) {},
                onDrag: (_, _) {},
                answerText: puzzle.finalShapeText,
                lineBreaks: puzzle.finalLineBreaks,
                maxTile: 40,
              ),
            ),
            if (puzzle.finalExplanation.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: p.sunken, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Why it works', style: t.titleSmall),
                    const SizedBox(height: 4),
                    Text(puzzle.finalExplanation, style: TextStyle(color: p.inkSoft, height: 1.4)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                _Stat(label: 'Time', value: game.timedOut ? 'N/A' : clock(game.elapsedAtCompletion ?? 0)),
                _Stat(label: 'Hints', value: '${game.hintsUsed}'),
                _Stat(label: 'Points', value: score != null ? '+${score.totalPoints}' : (game.scoring ? '…' : '–')),
              ],
            ),
            if (streak > 0 && !game.answersShown) ...[
              const SizedBox(height: 12),
              Text(
                streak == 1 ? '🔥 Streak started.' : '🔥 That makes $streak days in a row.',
                textAlign: TextAlign.center,
                style: t.titleMedium,
              ),
            ],
            const SizedBox(height: 12),
            if (score != null)
              _Breakdown(score: score)
            else
              Text(
                game.scoring
                    ? 'Adding up your points…'
                    : game.playedBefore
                    ? 'A replay earns no points.'
                    : 'Points are given for published puzzles, when you are signed in and online.',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.inkSoft),
              ),
            const SizedBox(height: 20),
            if (canShareWin(game)) ...[ShareWinButton(game: game), const SizedBox(height: 12)],
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onLeaderboard();
              },
              icon: const Icon(Icons.leaderboard_rounded),
              label: const Text('View Leaderboard'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: p.sunken, borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: TextStyle(color: p.inkSoft, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.score});
  final PuzzleScore score;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget line(String label, int points, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontWeight: strong ? FontWeight.w700 : FontWeight.w400)),
          const Spacer(),
          Text('$points', style: TextStyle(fontWeight: strong ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: p.rule),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          line('Words', score.wordPoints),
          line('Final answer', score.finalAnswerPoints),
          line(score.multiplier > 1 ? 'Speed ×${score.multiplier}' : 'Time bonus', score.timeBonus),
          if (score.latePenalty > 0) line('Half points — solved after its day', -score.latePenalty),
          const Divider(height: 16),
          line('Total', score.totalPoints, strong: true),
          if (score.alreadyScored)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Already scored — replays earn no new points.', style: TextStyle(color: p.inkSoft)),
            ),
          if (score.rank != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Current rank: #${score.rank}', style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
