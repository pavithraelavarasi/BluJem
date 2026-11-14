import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/slots.dart';
import '../../data/puzzle_library.dart';
import '../../data/records_repository.dart';
import '../../models/puzzle.dart';
import '../../models/records.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Every puzzle there is to play — a weekday's three slots, and Sunday's
/// Mega Jumble — in two windows: the month's calendar stays put at the top,
/// and the list under it scrolls on its own. Tapping a day shows just that
/// day's puzzles in the list; tapping it again shows them all.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.onOpen});
  final ValueChanged<Puzzle> onOpen;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _day;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<PuzzleLibrary>();
    final records = context.watch<RecordsRepository>();
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final runs = {for (final r in records.runs) r.puzzleId: r};
    // Each day's puzzles in slot order: morning, afternoon, night.
    final puzzleDays = <DateTime, List<Puzzle>>{};
    for (final x in library.available.reversed) {
      if (x.day != null) puzzleDays.putIfAbsent(dateOnly(x.day!), () => []).add(x);
    }
    final day = _day;
    final puzzles = day == null ? library.available : (puzzleDays[day] ?? const <Puzzle>[]);
    final today = indiaDate(DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PageTitle('History'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _MonthCalendar(
                month: _month,
                selected: day,
                puzzleDays: puzzleDays,
                solved: (p) => runs.containsKey(p.id),
                onMonth: (m) => setState(() {
                  _month = m;
                  _day = null;
                }),
                onPick: (picked) => setState(() => _day = picked == _day ? null : picked),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      day == null ? 'All puzzles' : _dayHeading(day, puzzles),
                      style: t.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (day != null)
                    TextButton(onPressed: () => setState(() => _day = null), child: const Text('Show all')),
                ],
              ),
            ),
            Divider(height: 1, color: p.rule),
            Expanded(
              child: RefreshIndicator(
                onRefresh: library.sync,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: puzzles.length,
                  separatorBuilder: (_, _) => Divider(indent: 20, endIndent: 20, color: p.rule),
                  itemBuilder: (context, i) => _PuzzleTile(
                    puzzle: puzzles[i],
                    run: runs[puzzles[i].id],
                    isToday: puzzles[i].publishDate == today,
                    onTap: () => widget.onOpen(puzzles[i]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Sunday Mega Jumble · Nov 16", or "Sat, Nov 14 · 2 of 3 solved".
  String _dayHeading(DateTime day, List<Puzzle> puzzles) {
    final date = dayLabel(isoDate(day));
    if (day.weekday == DateTime.sunday) return 'Sunday Mega Jumble · ${date.split(', ').last}';
    final records = context.read<RecordsRepository>();
    final solved = puzzles.where((p) => records.finished(p.id)).length;
    return '$date · $solved of ${puzzles.length} solved';
  }
}

class _PuzzleTile extends StatelessWidget {
  const _PuzzleTile({required this.puzzle, required this.run, required this.isToday, required this.onTap});
  final Puzzle puzzle;
  final Completion? run;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final done = run != null;
    final mega = puzzle.slotKind == Slot.sunday;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: done ? p.successSoft : (mega ? _megaSoft : p.sunken),
          borderRadius: BorderRadius.circular(14),
        ),
        child: done
            ? Icon(Icons.check_rounded, color: p.success)
            : Text(
                puzzle.day == null ? '?' : '${puzzle.day!.day}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              // The slot is in the line under it.
              dayLabel(puzzle.publishDate),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (mega) ...[const SizedBox(width: 8), const _Badge('MEGA', color: _mega, ink: Colors.white)],
          if (isToday) ...[const SizedBox(width: 8), _Badge('TODAY', color: p.accent)],
        ],
      ),
      subtitle: Text(
        done
            ? 'Solved · ${run!.hintsUsed} hint${run!.hintsUsed == 1 ? '' : 's'}'
            : '${puzzle.slotKind.label} · ${puzzle.words.length} words',
        style: TextStyle(color: p.inkSoft),
      ),
      trailing: Icon(done ? Icons.replay_rounded : Icons.play_arrow_rounded, color: p.ink),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {required this.color, this.ink = _medalInk});
  final String text;
  final Color color, ink;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ink),
    ),
  );
}

/// Sunday's Mega Jumble, set apart in blue: its column on the calendar, a
/// star on its days, and its badge in the list.
const _mega = Color(0xFF1E6FE0);
const _megaSoft = Color(0x331E6FE0);

/// A day's medal on the calendar: Gold when all its puzzles are solved,
/// Silver when some are, grey (the palette's sunken) when none are yet. The
/// same in dark mode, with dark numbers, so they read as medals.
const _gold = Color(0xFFE8C547);
const _silver = Color(0xFFC3C8CF);
const _medalInk = Color(0xFF1C1B19);

/// A month: tapping a puzzle day picks it. A day's colour is its medal, the
/// picked one is ringed in blue, and Sundays carry the Mega Jumble's star.
class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.selected,
    required this.puzzleDays,
    required this.solved,
    required this.onMonth,
    required this.onPick,
  });

  final DateTime month;
  final DateTime? selected;
  final Map<DateTime, List<Puzzle>> puzzleDays;
  final bool Function(Puzzle) solved;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final today = dateOnly(DateTime.now());
    final first = DateTime(month.year, month.month);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday % 7; // Sunday first.
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    '${monthDay(first).split(' ').first} ${month.year}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  onPressed: first.isBefore(DateTime(today.year, today.month))
                      ? () => onMonth(DateTime(month.year, month.month + 1))
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            Row(
              children: [
                for (final (i, d) in ['S', 'M', 'T', 'W', 'T', 'F', 'S'].indexed)
                  Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(color: i == 0 ? _mega : p.inkFaint, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              // Wider than tall, so the calendar leaves room for the list.
              childAspectRatio: 1.3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                for (var d = 1; d <= days; d++)
                  () {
                    final day = DateTime(month.year, month.month, d);
                    final list = puzzleDays[day] ?? const <Puzzle>[];
                    final hasPuzzle = list.isNotEmpty;
                    final count = list.where(this.solved).length;
                    final solved = hasPuzzle && count == list.length;
                    final some = count > 0 && !solved;
                    final isToday = day == today;
                    final picked = day == selected;
                    final sunday = day.weekday == DateTime.sunday;
                    final medal = solved ? _gold : (some ? _silver : null);
                    return Padding(
                      padding: const EdgeInsets.all(2),
                      child: Material(
                        color: medal ?? (hasPuzzle ? p.sunken : Colors.transparent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: picked
                              ? const BorderSide(color: _mega, width: 3)
                              : (isToday ? BorderSide(color: p.ink, width: 2) : BorderSide.none),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: hasPuzzle ? () => onPick(day) : null,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                '$d',
                                style: TextStyle(
                                  fontWeight: hasPuzzle ? FontWeight.w700 : FontWeight.w400,
                                  color: medal != null ? _medalInk : (hasPuzzle ? p.ink : p.inkFaint),
                                ),
                              ),
                              if (sunday && hasPuzzle)
                                const Positioned(
                                  top: 2,
                                  right: 3,
                                  child: Icon(Icons.star_rounded, size: 11, color: _mega),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }(),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 6,
              children: [
                const _Legend(color: _gold, label: 'Gold · all solved'),
                const _Legend(color: _silver, label: 'Silver · some'),
                _Legend(color: p.sunken, label: 'Not solved'),
                const _Legend(color: _mega, label: 'Sunday Mega', star: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.star = false});
  final Color color;
  final String label;

  /// Shown as the calendar's star rather than a swatch.
  final bool star;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (star)
        Icon(Icons.star_rounded, size: 14, color: color)
      else
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: context.palette.inkSoft, fontSize: 12)),
    ],
  );
}
