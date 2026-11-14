import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/slots.dart';
import '../../data/auth_repository.dart';
import '../../data/puzzle_library.dart';
import '../../data/records_repository.dart';
import '../../game/game_controller.dart';
import '../../models/puzzle.dart';
import '../../models/records.dart';
import '../share_card.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Today at a glance: the newest puzzle out, every slot of today's (morning
/// afternoon and night, or Sunday's Mega Jumble) with when a locked one opens, and
/// the streak.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onPlayToday, required this.onOpen});
  final VoidCallback onPlayToday;
  final ValueChanged<Puzzle> onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final game = context.watch<GameController>();
    final library = context.watch<PuzzleLibrary>();
    final records = context.watch<RecordsRepository>();
    final account = context.watch<AuthRepository>().account;
    final stats = records.stats;
    final day = library.dayPuzzle;

    // Where the day's sheet stands: from the board when it is the one in
    // play, otherwise from what this player has finished.
    final onBoard = game.puzzle.id == day.id;
    final status = records.finished(day.id) || (onBoard && game.status == RunStatus.completed)
        ? RunStatus.completed
        : onBoard
        ? game.status
        : RunStatus.notStarted;
    final awaiting = library.dayKind == DayKind.awaiting;
    final standIn = library.dayKind == DayKind.standIn;
    final finishedStandIn = standIn && records.finished(day.id);
    final upcoming = library.upcomingToday;
    final next = upcoming.isEmpty ? null : upcoming.first;
    final slotName = _slotName(day);
    final whenNext = next == null
        ? 'Come back tomorrow for new ones.'
        : 'The ${next.$1.label.toLowerCase()} puzzle unlocks at ${next.$1.time}.';

    final (headline, body, button) = switch ((awaiting, standIn, status)) {
      (true, _, _) => (
        "Today's puzzle isn't up yet",
        "We'll let you in the moment it's published.",
        'Check the puzzle page',
      ),
      (_, true, _) when finishedStandIn => (
        "Today's puzzle isn't up yet",
        'You already finished ${library.standInDayName()} puzzle — play it again for fun, no points this time.',
        'Play Again (No Points)',
      ),
      (_, true, RunStatus.inProgress) => (
        "Today's puzzle isn't up yet",
        'Carry on with ${library.standInDayName()} puzzle while you wait.',
        "Continue ${_title(library.standInDayName())} Jumble",
      ),
      (_, true, _) => (
        "Today's puzzle isn't up yet",
        'Play ${library.standInDayName()} puzzle while you wait.',
        "Play ${_title(library.standInDayName())} Jumble",
      ),
      (_, _, RunStatus.completed) => (
        '$slotName: done!',
        whenNext,
        'See your ${day.slotKind.label.toLowerCase()} puzzle',
      ),
      (_, _, RunStatus.inProgress) => (
        slotName,
        'Your run is underway — the clock is waiting.',
        'Continue · ${day.slotKind.label}',
      ),
      _ => (slotName, 'Unscramble the words, then crack the cartoon riddle.', 'Play now · ${day.slotKind.label}'),
    };

    // The card above already opens the day's puzzle, so the list shows only
    // today's other slots: the later ones' locks, or the earlier ones still to play.
    final shownAbove = awaiting || standIn ? null : day.slotKind;
    final otherSlots = [
      for (final slot in Slot.forDate(indiaDate(DateTime.now())))
        if (slot != shownAbove) slot,
    ];

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: library.sync,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Image.asset('assets/images/blujem_logo.png', height: 36, semanticLabel: 'BluJem'),
                  const Spacer(),
                  Builder(
                    builder: (button) => IconButton(
                      tooltip: 'Share BluJem',
                      onPressed: () => shareApp(button, stats: stats),
                      icon: const Icon(Icons.ios_share_rounded),
                    ),
                  ),
                  StreakPill(days: stats.currentStreak, safe: stats.solvedToday),
                ],
              ),
              const SizedBox(height: 20),
              Text('${greeting(DateTime.now())}, ${_firstName(account?.displayName)}!', style: t.headlineMedium),
              Text(longDate(), style: TextStyle(color: p.inkSoft)),
              const SizedBox(height: 20),
              _TodayCard(
                headline: headline,
                body: body,
                button: button,
                status: status,
                slot: awaiting ? null : day.slotKind.heading,
                difficulty: day.difficulty,
                minutes: day.timeLimitSeconds ~/ 60,
                onPlay: onPlayToday,
              ),
              if (otherSlots.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(shownAbove == null ? "Today's puzzles" : 'Also today', style: t.titleMedium),
                const SizedBox(height: 8),
              ],
              for (final slot in otherSlots)
                _SlotTile(
                  slot: slot,
                  puzzle: library.todaysPuzzles.where((p) => p.slotKind == slot).firstOrNull,
                  locked: upcoming.any((u) => u.$1 == slot),
                  solved: (p) => records.finished(p.id),
                  onOpen: onOpen,
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  StatTile(
                    label: 'Solved',
                    value: '${stats.puzzlesCompleted}',
                    icon: Icons.check_circle_outline_rounded,
                  ),
                  const SizedBox(width: 10),
                  StatTile(
                    label: 'Best streak',
                    value: '${stats.longestStreak}',
                    icon: Icons.local_fire_department_outlined,
                  ),
                  const SizedBox(width: 10),
                  StatTile(
                    label: "Today's medal",
                    value:
                        medalFor(
                          library.todaysPuzzles.where((p) => records.finished(p.id)).length,
                          ofDay: Slot.forDate(indiaDate(DateTime.now())).length,
                        ) ??
                        '—',
                    icon: Icons.emoji_events_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  '“The answer is always in the circles.”',
                  style: TextStyle(color: p.inkFaint, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Good Morning" before noon, "Good Afternoon" until 5 PM, then "Good
  /// Evening" — on the phone's own clock, wherever the player is.
  @visibleForTesting
  static String greeting(DateTime now) => now.hour < 12
      ? 'Good Morning'
      : now.hour < 17
      ? 'Good Afternoon'
      : 'Good Evening';

  static String _firstName(String? name) => (name ?? '').trim().split(RegExp(r'[\s@]')).first.isEmpty
      ? 'there'
      : (name ?? '').trim().split(RegExp(r'[\s@]')).first;

  /// "This morning's jumble", "Sunday Mega Jumble", "Today's jumble".
  static String _slotName(Puzzle day) => switch (Slot.tryParse(day.slot)) {
    Slot.morning => "This morning's jumble",
    Slot.evening => "This afternoon's jumble",
    Slot.night => "Tonight's jumble",
    Slot.sunday => 'Sunday Mega Jumble',
    null => "Today's jumble",
  };

  /// "yesterday's" → "Yesterday's".
  static String _title(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// One of today's slots: open to play, solved, or locked until its time.
class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.slot,
    required this.puzzle,
    required this.locked,
    required this.solved,
    required this.onOpen,
  });

  final Slot slot;
  final Puzzle? puzzle;
  final bool locked;
  final bool Function(Puzzle) solved;
  final ValueChanged<Puzzle> onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ready = puzzle;
    final done = ready != null && solved(ready);
    final (subtitle, icon) = ready != null
        ? (
            done ? 'Solved' : '${slot.words} words · ready to play',
            done ? Icons.verified_rounded : Icons.play_arrow_rounded,
          )
        : locked
        ? ('Unlocks at ${slot.time}', Icons.lock_clock_rounded)
        : (
            slot.opensOnPublish ? "Not out yet — we'll notify you" : 'Not out yet — check back soon',
            Icons.hourglass_empty_rounded,
          );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: ready == null ? null : () => onOpen(ready),
        leading: Icon(switch (slot) {
          Slot.evening => Icons.wb_twilight_rounded,
          Slot.night => Icons.nights_stay_rounded,
          _ => Icons.wb_sunny_rounded,
        }, color: ready == null ? p.inkFaint : p.accent),
        title: Text(slot.heading, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(color: p.inkSoft)),
        trailing: Icon(icon, color: done ? p.success : (ready == null ? p.inkFaint : p.ink)),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.headline,
    required this.body,
    required this.button,
    required this.status,
    required this.slot,
    required this.difficulty,
    required this.minutes,
    required this.onPlay,
  });

  final String headline, body, button, difficulty;
  final String? slot;
  final RunStatus status;
  final int minutes;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(colors: [p.rows[2], p.rows[0]], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (slot != null) ...[_Chip(text: slot!), const SizedBox(width: 8)],
              _Chip(text: difficulty),
              const SizedBox(width: 8),
              _Chip(text: '$minutes min'),
              const Spacer(),
              if (status == RunStatus.completed) Icon(Icons.verified_rounded, color: p.success, size: 28),
            ],
          ),
          const SizedBox(height: 16),
          const _MiniTiles(),
          const SizedBox(height: 16),
          Text(headline, style: t.headlineSmall),
          const SizedBox(height: 4),
          Text(body, style: TextStyle(color: p.ink.withValues(alpha: 0.75), height: 1.35)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPlay,
              icon: Icon(status == RunStatus.completed ? Icons.visibility_rounded : Icons.play_arrow_rounded),
              label: Text(button),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: context.palette.card.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
  );
}

/// A decorative "JUMBLE" in tiles — never the day's letters.
class _MiniTiles extends StatelessWidget {
  const _MiniTiles();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ExcludeSemantics(
      child: Row(
        children: [
          for (final (i, c) in 'BLUJEM'.split('').indexed)
            Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.tile,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color.lerp(p.rowColor(i), p.ink, 0.25)!, width: 2),
                boxShadow: [BoxShadow(color: Color.lerp(p.rowColor(i), p.ink, 0.25)!, offset: const Offset(0, 2))],
              ),
              child: Text(c, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            ),
        ],
      ),
    );
  }
}
