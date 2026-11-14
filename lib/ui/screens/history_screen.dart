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

/// Every puzzle there is to play — both of a weekday's slots, and Sunday's
/// Mega Jumble — on a calendar and in a list, with this player's result
/// beside each.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.onOpen});
  final ValueChanged<Puzzle> onOpen;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final library = context.watch<PuzzleLibrary>();
    final records = context.watch<RecordsRepository>();
    final p = context.palette;
    final puzzles = library.all;
    final runs = {for (final r in records.runs) r.puzzleId: r};
    // Each day's puzzles in slot order: morning, afternoon, night.
    final puzzleDays = <DateTime, List<Puzzle>>{};
    for (final x in puzzles.reversed) {
      if (x.day != null) puzzleDays.putIfAbsent(dateOnly(x.day!), () => []).add(x);
    }
    final today = indiaDate(DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: library.sync,
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: PageTitle('History')),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _MonthCalendar(
                    month: _month,
                    puzzleDays: puzzleDays,
                    solved: (p) => runs.containsKey(p.id),
                    onMonth: (m) => setState(() => _month = m),
                    onPick: (day) {
                      final list = puzzleDays[day] ?? const [];
                      if (list.length == 1) widget.onOpen(list.first);
                      if (list.length > 1) _pickSlot(list, runs);
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text('All puzzles', style: Theme.of(context).textTheme.titleMedium),
                ),
              ),
              SliverList.separated(
                itemCount: puzzles.length,
                separatorBuilder: (_, _) => Divider(indent: 20, endIndent: 20, color: p.rule),
                itemBuilder: (context, i) => _PuzzleTile(
                  puzzle: puzzles[i],
                  run: runs[puzzles[i].id],
                  isToday: puzzles[i].publishDate == today,
                  onTap: () => widget.onOpen(puzzles[i]),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  /// A day with two puzzles: which one.
  void _pickSlot(List<Puzzle> list, Map<String, Completion> runs) => showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(longDate(list.first.publishDate), style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final puzzle in list)
            ListTile(
              leading: Icon(runs.containsKey(puzzle.id) ? Icons.verified_rounded : Icons.play_arrow_rounded),
              title: Text(puzzle.slotKind.heading),
              subtitle: Text(runs.containsKey(puzzle.id) ? 'Solved' : '${puzzle.words.length} words'),
              onTap: () {
                Navigator.pop(sheet);
                widget.onOpen(puzzle);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
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
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: done ? p.successSoft : p.sunken, borderRadius: BorderRadius.circular(14)),
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
              '${longDate(puzzle.publishDate)}${puzzle.slotKind.opensOnPublish ? '' : ' · ${puzzle.slotKind.label}'}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isToday) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(6)),
              child: const Text(
                'TODAY',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1C1B19)),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        done
            ? '${run!.timed ? clock(run!.seconds) : 'N/A'} · ${run!.hintsUsed} hint${run!.hintsUsed == 1 ? '' : 's'}'
            : '${puzzle.slotKind.label} · ${puzzle.words.length} words',
        style: TextStyle(color: p.inkSoft),
      ),
      trailing: Icon(done ? Icons.replay_rounded : Icons.play_arrow_rounded, color: p.ink),
    );
  }
}

/// A month: puzzle days can be opened; a day whose puzzles are all solved is
/// filled, one with some solved is half filled.
/// A day's medal on the calendar: Gold when all its puzzles are solved,
/// Silver when some are, grey (the palette's sunken) when none are yet. The
/// same in dark mode, with dark numbers, so they read as medals.
const _gold = Color(0xFFE8C547);
const _silver = Color(0xFFC3C8CF);
const _medalInk = Color(0xFF1C1B19);

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.puzzleDays,
    required this.solved,
    required this.onMonth,
    required this.onPick,
  });

  final DateTime month;
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
                for (final d in ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                  Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(color: p.inkFaint, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
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
                    final medal = solved ? _gold : (some ? _silver : null);
                    return Padding(
                      padding: const EdgeInsets.all(3),
                      child: Material(
                        color: medal ?? (hasPuzzle ? p.sunken : Colors.transparent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: isToday ? BorderSide(color: p.ink, width: 2) : BorderSide.none,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: hasPuzzle ? () => onPick(day) : null,
                          child: Center(
                            child: Text(
                              '$d',
                              style: TextStyle(
                                fontWeight: hasPuzzle ? FontWeight.w700 : FontWeight.w400,
                                color: medal != null ? _medalInk : (hasPuzzle ? p.ink : p.inkFaint),
                              ),
                            ),
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
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
