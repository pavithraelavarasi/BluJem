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
/// afternoon and night, or Sunday's Mega BluJem) with when a locked one opens, and
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
    // The puzzle for now: the slot open at this hour (the night one after
    // 9 PM). Once that is solved, the latest of today's still to play, so a
    // player who comes late in the day is led through all of them.
    final current = library.dayPuzzle;
    final isToday = library.dayKind == DayKind.today;
    final day = isToday && records.finished(current.id)
        ? library.todaysPuzzles.lastWhere((p) => !records.finished(p.id), orElse: () => current)
        : current;

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

    // Before the first check with the server, "not up yet" would be a guess.
    final loading = awaiting && !library.checked;
    final (headline, body, button) = switch ((awaiting, standIn, status)) {
      (true, _, _) when loading => ("Getting today's puzzles…", 'One moment.', 'Loading…'),
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
        "Continue ${_title(library.standInDayName())} BluJem",
      ),
      (_, true, _) => (
        "Today's puzzle isn't up yet",
        'Play ${library.standInDayName()} puzzle while you wait.',
        "Play ${_title(library.standInDayName())} BluJem",
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
      _ => (slotName, 'Unscramble the words, then crack the cartoon riddle.', 'Start Puzzle · ${day.slotKind.label}'),
    };

    // Every one of today's slots, the one for this hour highlighted: the
    // latest whose time has come (none before 9 AM, or 6 AM on Sunday).
    final todayIso = indiaDate(DateTime.now());
    final slots = Slot.forDate(todayIso);
    final nowSlot = slots.lastWhere((s) => !slotStart(todayIso, s).isAfter(DateTime.now()), orElse: () => slots.first);
    final beforeFirst = slotStart(todayIso, slots.first).isAfter(DateTime.now());

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
                onPlay: loading ? null : (isToday ? () => onOpen(day) : onPlayToday),
              ),
              const SizedBox(height: 20),
              Text("Today's puzzles", style: t.titleMedium),
              const SizedBox(height: 8),
              for (final slot in slots)
                _SlotTile(
                  slot: slot,
                  now: !beforeFirst && slot == nowSlot,
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

  /// "This morning's BluJem", "Sunday Mega BluJem", "Today's BluJem".
  static String _slotName(Puzzle day) => switch (Slot.tryParse(day.slot)) {
    Slot.morning => "This morning's BluJem",
    Slot.evening => "This afternoon's BluJem",
    Slot.night => "Tonight's BluJem",
    Slot.sunday => 'Sunday Mega BluJem',
    null => "Today's BluJem",
  };

  /// "yesterday's" → "Yesterday's".
  static String _title(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// One of today's slots: open to play, solved, or locked until its time.
class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.slot,
    required this.now,
    required this.puzzle,
    required this.locked,
    required this.solved,
    required this.onOpen,
  });

  final Slot slot;

  /// This hour's slot: ringed in the accent and marked NOW.
  final bool now;
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
        ? (done ? 'Solved' : 'Ready to play', done ? Icons.verified_rounded : Icons.play_arrow_rounded)
        : locked
        ? ('Unlocks at ${slot.time}', Icons.lock_clock_rounded)
        : (
            slot.opensOnPublish ? "Not out yet — we'll notify you" : 'Not out yet — check back soon',
            Icons.hourglass_empty_rounded,
          );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: now ? p.accentSoft : null,
      shape: now
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: p.accent, width: 2.5),
            )
          : null,
      child: ListTile(
        onTap: ready == null ? null : () => onOpen(ready),
        leading: Icon(switch (slot) {
          Slot.evening => Icons.wb_twilight_rounded,
          Slot.night => Icons.nights_stay_rounded,
          _ => Icons.wb_sunny_rounded,
        }, color: ready == null ? p.inkFaint : p.accent),
        title: Row(
          children: [
            Flexible(
              child: Text(
                slot.heading,
                style: TextStyle(fontWeight: now ? FontWeight.w800 : FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (now) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(6)),
                child: const Text(
                  'NOW',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1C1B19)),
                ),
              ),
            ],
          ],
        ),
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
    required this.onPlay,
  });

  final String headline, body, button;
  final String? slot;
  final RunStatus status;

  /// Null while today's puzzles are still loading.
  final VoidCallback? onPlay;

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
          if (slot != null || status == RunStatus.completed) ...[
            Row(
              children: [
                if (slot != null) _Chip(text: slot!),
                const Spacer(),
                if (status == RunStatus.completed) Icon(Icons.verified_rounded, color: p.success, size: 28),
              ],
            ),
            const SizedBox(height: 16),
          ],
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
