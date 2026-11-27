import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_refresh.dart';
import '../../data/profile_service.dart';
import '../../data/score_repository.dart';
import '../../models/records.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// The points board for today, this week or all time.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => LeaderboardScreenState();
}

class LeaderboardScreenState extends State<LeaderboardScreen> {
  ScorePeriod _period = ScorePeriod.allTime;
  final _boards = <ScorePeriod, ScoreBoard>{};
  bool _loading = false;
  bool _unavailable = false;

  AppRefresh? _appRefresh;

  @override
  void initState() {
    super.initState();
    refresh();
    // Reload with the rest of the app: on coming back, and every few minutes.
    try {
      _appRefresh = context.read<AppRefresh>()..addListener(_onAppRefresh);
    } on ProviderNotFoundException {
      // A screen shown on its own (tests) has nothing to listen to.
    }
  }

  void _onAppRefresh() {
    if (mounted && !_loading) refresh();
  }

  @override
  void dispose() {
    _appRefresh?.removeListener(_onAppRefresh);
    super.dispose();
  }

  Future<void> refresh() async {
    final period = _period;
    setState(() => _loading = true);
    final board = await context.read<ScoreRepository>().leaderboard(period);
    if (!mounted || period != _period) return;
    setState(() {
      // A failed fetch keeps the last board rather than blanking it.
      if (board != null) _boards[period] = board;
      _unavailable = board == null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final board = _boards[_period];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageTitle(
              'Leaderboard',
              trailing: IconButton(onPressed: _loading ? null : refresh, icon: const Icon(Icons.refresh_rounded)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ScorePeriod>(
                  segments: [for (final s in ScorePeriod.values) ButtonSegment(value: s, label: Text(s.label))],
                  selected: {_period},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) {
                    setState(() => _period = s.first);
                    refresh();
                  },
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: p.accent,
                    selectedForegroundColor: p.tileInk,
                    textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2) else const SizedBox(height: 2),
            if (board != null && board.myRank != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(18)),
                  child: Row(
                    children: [
                      Text('#${board.myRank}', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(width: 16),
                      Expanded(child: Text('Your place', style: Theme.of(context).textTheme.titleMedium)),
                      Text('${board.myPoints} pts', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: refresh,
                child: board == null || board.entries.isEmpty
                    ? ListView(
                        children: [
                          if (!_loading)
                            EmptyState(
                              icon: _unavailable ? Icons.cloud_off_rounded : Icons.emoji_events_outlined,
                              title: _unavailable ? "Couldn't load the leaderboard" : 'No scores yet',
                              body: _unavailable
                                  ? 'Check your connection and pull to try again.'
                                  : 'Finish a published puzzle to get on the board.',
                            ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: board.entries.length,
                        itemBuilder: (_, i) => _Row(entry: board.entries[i]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry});
  final ScoreEntry entry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const medals = [Color(0xFFE8C547), Color(0xFFC0C4CC), Color(0xFFD08B4F)];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: entry.you ? p.accentSoft : p.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: entry.you ? p.accent : p.rule),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: entry.key.startsWith('row') ? null : () => showPlayerProfile(context, entry),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: entry.rank <= 3 ? medals[entry.rank - 1] : p.sunken,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${entry.rank}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: entry.rank <= 3 ? const Color(0xFF1C1B19) : p.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.you ? '${entry.name} (you)' : entry.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${entry.puzzles} puzzle${entry.puzzles == 1 ? '' : 's'}',
                        style: TextStyle(color: p.inkSoft, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text('${entry.points}', style: Theme.of(context).textTheme.titleMedium),
                Text(' pts', style: TextStyle(color: p.inkSoft)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A player's name and About me, from a tap on their leaderboard row.
Future<void> showPlayerProfile(BuildContext context, ScoreEntry entry) {
  final service = context.read<ProfileService>();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final p = context.palette;
      final t = Theme.of(context).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: FutureBuilder<PlayerProfile?>(
            future: service.load(key: entry.key),
            builder: (context, snap) {
              final profile = snap.data;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.you ? '${entry.name} (you)' : entry.name, style: t.titleLarge),
                  Text(
                    '#${entry.rank} · ${entry.points} pts · ${entry.puzzles} puzzle${entry.puzzles == 1 ? '' : 's'}',
                    style: TextStyle(color: p.inkSoft),
                  ),
                  const SizedBox(height: 16),
                  if (snap.connectionState != ConnectionState.done)
                    const Center(child: CircularProgressIndicator())
                  else if (profile == null)
                    Text("Couldn't load this player's profile.", style: TextStyle(color: p.inkSoft))
                  else if (profile.about.isEmpty)
                    Text(
                      profile.you
                          ? 'Add an About me on your Profile page so other players can get to know you.'
                          : "${entry.name} hasn't written an About me yet.",
                      style: TextStyle(color: p.inkSoft),
                    )
                  else
                    SelectableText(profile.about, style: const TextStyle(height: 1.4)),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}
