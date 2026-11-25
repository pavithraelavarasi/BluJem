import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/slots.dart';
import '../../game/game_controller.dart';
import '../../models/puzzle.dart';
import '../../models/records.dart';
import '../share_card.dart';
import '../theme.dart';
import 'share_win_button.dart';
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

/// Before Start: a game lobby. The slot's hero with bouncing BluJem tiles
/// (never the cartoon), the player's streak, best time and the medal up for
/// grabs, and the speed bonus to chase. How to play is behind the help button
/// ([showHowToPlay]); the Start button is [StartBar], pinned below.
class StartCard extends StatelessWidget {
  const StartCard({
    super.key,
    required this.game,
    required this.fromDay,
    required this.pointsOn,
    this.streak = 0,
    this.bestSeconds,
  });
  final GameController game;

  /// The sheet's day when it is not today's, for the time line.
  final String? fromDay;
  final bool pointsOn;

  /// The player's current streak in days, and fastest solve, for the stats row.
  final int streak;
  final int? bestSeconds;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final puzzle = game.puzzle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StartArt(puzzle: puzzle, replay: game.playedBefore),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.local_fire_department_rounded,
                color: const Color(0xFFFF7A2F),
                value: streak > 0 ? '$streak' : 'Start',
                label: streak > 0 ? 'day streak' : 'a streak today',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                icon: Icons.timer_rounded,
                color: const Color(0xFF1E6FE0),
                value: bestSeconds == null ? '—' : shortClock(bestSeconds!),
                label: 'your best',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                icon: Icons.emoji_events_rounded,
                color: const Color(0xFFD4A21A),
                value: pointsOn ? 'Gold' : '—',
                label: pointsOn ? 'up for grabs' : 'no points',
              ),
            ),
          ],
        ),
        if (pointsOn && !game.earnsHalf) ...[const SizedBox(height: 14), const BonusLadder()],
        if (fromDay != null) ...[
          const SizedBox(height: 14),
          Text('This puzzle is from $fromDay.', style: TextStyle(color: p.inkSoft, height: 1.4)),
        ],
        if (pointsOn && game.earnsHalf) ...[
          const SizedBox(height: 10),
          const _Rule(
            icon: Icons.history_rounded,
            text: 'This puzzle is from an earlier day, so it earns half points. Full points are for solving on the day it comes out.',
          ),
        ],
        if (canShareWin(game)) ...[const SizedBox(height: 12), ShareWinButton(game: game)],
        if (game.earnsHalf || game.playedBefore) ...[
          const SizedBox(height: 4),
          Center(
            child: TextButton.icon(
              onPressed: () async {
                if (await confirmShowAnswers(context)) unawaited(game.showAnswers());
              },
              icon: const Icon(Icons.visibility_outlined),
              label: Text('Just show me the answers', style: t.labelLarge),
            ),
          ),
        ],
      ],
    );
  }
}

/// One number in the lobby's stats row: an icon in its colour, the value big,
/// what it is small.
class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.color, required this.value, required this.label});
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.rule),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: p.ink, height: 1.1),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: p.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// The speed bonus to chase, as a ladder: 5x inside a minute down to 2x by
/// three minutes.
class BonusLadder extends StatelessWidget {
  const BonusLadder({super.key});

  static const _colors = [Color(0xFFFF5A5F), Color(0xFFFF8A3D), Color(0xFFF5B82E), Color(0xFF8BC34A)];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 20, color: Color(0xFFFF8A3D)),
              const SizedBox(width: 4),
              Text(
                'Speed bonus',
                style: TextStyle(fontWeight: FontWeight.w800, color: p.ink, fontSize: 15),
              ),
              const Spacer(),
              Text('finish faster, score more', style: TextStyle(fontSize: 12.5, color: p.inkSoft)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final (i, (limit, x)) in Multipliers.tiers.indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_colors[i], _colors[i].withValues(alpha: 0.78)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${x}x',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        Text(
                          '≤ ${shortClock(limit)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// One line for the start screen: a nudge for the puzzle's slot. Never its
/// riddle, which waits until the clock starts.
String teaserLine(Puzzle puzzle) => switch (puzzle.slotKind) {
  Slot.morning => 'This morning’s cartoon is hiding a pun. Can you crack it?',
  Slot.evening => 'This afternoon’s cartoon is hiding a pun. Can you crack it?',
  Slot.night => 'Tonight’s cartoon is hiding a pun. Can you crack it?',
  Slot.sunday => 'Sunday’s Mega BluJem: six words and a bigger riddle. Can you crack it?',
};

/// The lobby's hero: the slot's sky — sunrise, afternoon sun, night stars,
/// Sunday's big day — with its name, the day, BLUJEM in bouncing gold tiles,
/// and the teaser. Nothing of the puzzle itself, so no one sees the cartoon
/// or its riddle before the clock starts.
class StartArt extends StatelessWidget {
  const StartArt({super.key, required this.puzzle, this.replay = false});
  final Puzzle puzzle;
  final bool replay;

  @override
  Widget build(BuildContext context) {
    final (colors, icon, label) = switch (puzzle.slotKind) {
      Slot.morning => (
        const [Color(0xFFFFB86B), Color(0xFFFF6F91), Color(0xFFB45CFF)],
        Icons.wb_sunny_rounded,
        'MORNING BLUJEM',
      ),
      Slot.evening => (
        const [Color(0xFF3FC5FF), Color(0xFF4F8BFF), Color(0xFFFF9F43)],
        Icons.wb_twilight_rounded,
        'AFTERNOON BLUJEM',
      ),
      Slot.night => (
        const [Color(0xFF0F1B4D), Color(0xFF3B2A8F), Color(0xFF8A3FD1)],
        Icons.nights_stay_rounded,
        'NIGHT BLUJEM',
      ),
      Slot.sunday => (
        const [Color(0xFF1E6FE0), Color(0xFF7A4CE0), Color(0xFFFF4FA3)],
        Icons.auto_awesome_rounded,
        'SUNDAY MEGA BLUJEM',
      ),
    };
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: colors[1].withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Sparkles across the sky.
          for (final (x, y, size) in const [
            (0.06, 0.12, 10.0),
            (0.2, 0.3, 7.0),
            (0.88, 0.62, 9.0),
            (0.5, 0.08, 6.0),
            (0.94, 0.9, 7.0),
            (0.1, 0.82, 8.0),
            (0.7, 0.2, 5.0),
          ])
            Align(
              alignment: Alignment(x * 2 - 1, y * 2 - 1),
              child: Icon(Icons.star_rounded, size: size + 4, color: Colors.white.withValues(alpha: 0.45)),
            ),
          Positioned(right: -18, top: -18, child: Icon(icon, size: 120, color: Colors.white.withValues(alpha: 0.18))),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [_Pill(icon: icon, text: label)],
                ),
                const SizedBox(height: 26),
                const BouncingTiles(word: 'BLUJEM'),
                const SizedBox(height: 24),
                Text(
                  replay ? 'Play it again?' : 'Ready to play?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: [Shadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 2))],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  teaserLine(puzzle),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15.5, height: 1.35, color: Colors.white.withValues(alpha: 0.92)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A frosted label on the hero.
class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 16, color: Colors.white), const SizedBox(width: 6)],
        Text(
          text,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5, letterSpacing: 1.2),
        ),
      ],
    ),
  );
}

/// [word] in the game's gold tiles, each tipped a little and bobbing in turn,
/// like letters waiting to be sorted.
class BouncingTiles extends StatefulWidget {
  const BouncingTiles({super.key, required this.word});
  final String word;

  @override
  State<BouncingTiles> createState() => _BouncingTilesState();
}

class _BouncingTilesState extends State<BouncingTiles> with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void initState() {
    super.initState();
    // Still for anyone who asked for less motion, and in tests.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !MediaQuery.of(context).disableAnimations) _wave.repeat();
    });
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final n = widget.word.length;
      final tile = ((box.maxWidth - (n - 1) * 8) / n).clamp(0.0, 54.0);
      return AnimatedBuilder(
        animation: _wave,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Transform.translate(
                // Each tile hops in turn: a short lift, then rest.
                offset: Offset(0, -10 * _hop(_wave.value - i / (n * 1.6))),
                child: Transform.rotate(
                  angle: (i.isEven ? -1 : 1) * 0.08,
                  child: _GoldTile(letter: widget.word[i], size: tile),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );

  /// 0 at rest, up to 1 at the top of a hop that takes the first fifth of
  /// each cycle.
  static double _hop(double t) {
    final phase = t - t.floorToDouble();
    if (phase > 0.2) return 0;
    final x = phase / 0.2;
    return 4 * x * (1 - x);
  }
}

class _GoldTile extends StatelessWidget {
  const _GoldTile({required this.letter, required this.size});
  final String letter;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFE07A), Color(0xFFE8C547)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      borderRadius: BorderRadius.circular(size * 0.2),
      boxShadow: [
        const BoxShadow(color: Color(0xFFB8952A), offset: Offset(0, 4)),
        BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 6)),
      ],
    ),
    child: Text(
      letter,
      style: TextStyle(fontSize: size * 0.56, fontWeight: FontWeight.w900, color: const Color(0xFF3A2A05)),
    ),
  );
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
      'Stuck? Hint sends the letter under the cursor to its right place, and it stays there. Each hint takes a little off that word’s points.',
      'Swipe to the cartoon, read the riddle, and arrange the circled letters into the answer.',
      'The faster you finish, the more you score.',
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

/// The one thing to do before a puzzle: Start, pinned under the lobby so it
/// is always in view, glowing gently to be tapped.
class StartBar extends StatefulWidget {
  const StartBar({super.key, required this.game});
  final GameController game;

  @override
  State<StartBar> createState() => _StartBarState();
}

class _StartBarState extends State<StartBar> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !MediaQuery.of(context).disableAnimations) _pulse.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final game = widget.game;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.paper,
        border: Border(top: BorderSide(color: p.rule)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_pulse.value);
            return Transform.scale(
              scale: 1 + 0.025 * t,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.25 + 0.3 * t),
                      blurRadius: 14 + 12 * t,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: FilledButton.icon(
            onPressed: game.start,
            icon: const Icon(Icons.play_arrow_rounded, size: 28),
            label: Text(game.playedBefore ? 'Play Again (No Points)' : "Let's Play!"),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(60),
              backgroundColor: const Color(0xFFFFC72C),
              foregroundColor: const Color(0xFF1C1B19),
              textStyle: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: 0.3),
            ),
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

/// The finish: the answer, why it is funny, time and points.
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
