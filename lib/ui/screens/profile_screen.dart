import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../data/auth_repository.dart';
import '../../data/profile_service.dart';
import '../../data/puzzle_library.dart';
import '../../data/records_repository.dart';
import '../../models/records.dart';
import '../feedback.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Who is playing, their record, and their settings.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final auth = context.watch<AuthRepository>();
    final records = context.watch<RecordsRepository>();
    final library = context.watch<PuzzleLibrary>();
    final stats = records.stats;
    final feedback = context.watch<GameFeedback>();
    final account = auth.account;
    if (account == null) return const SizedBox.shrink();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const PageTitle('Profile'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: p.rows[2],
                    child: Text(
                      account.displayName.isEmpty ? '?' : account.displayName[0].toUpperCase(),
                      style: t.headlineSmall,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(account.displayName, style: t.titleLarge, overflow: TextOverflow.ellipsis),
                        Text(
                          account.email,
                          style: TextStyle(color: p.inkSoft),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  StreakPill(days: stats.currentStreak, safe: stats.solvedToday),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      StatTile(
                        label: 'Solved',
                        value: '${stats.puzzlesCompleted}',
                        icon: Icons.check_circle_outline_rounded,
                      ),
                      const SizedBox(width: 10),
                      StatTile(
                        label: 'Current streak',
                        value: '${stats.currentStreak}',
                        icon: Icons.local_fire_department_outlined,
                      ),
                      const SizedBox(width: 10),
                      StatTile(
                        label: 'Longest streak',
                        value: '${stats.longestStreak}',
                        icon: Icons.military_tech_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      StatTile(
                        label: "Today's medal",
                        value: medalFor(library.todaysPuzzles.where((p) => records.finished(p.id)).length) ?? '—',
                        icon: Icons.emoji_events_outlined,
                      ),
                      const SizedBox(width: 10),
                      StatTile(label: 'Hints used', value: '${stats.hintsUsed}', icon: Icons.lightbulb_outline_rounded),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _Section(children: [_AboutTile()]),
            const SizedBox(height: 12),
            _Section(
              children: [
                ListTile(
                  leading: const Icon(Icons.alternate_email_rounded),
                  title: const Text('Leaderboard name'),
                  subtitle: Text(account.username.isEmpty ? 'Not set' : account.username),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _changeUsername(context, account.username),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up_outlined),
                  title: const Text('Sound'),
                  value: !feedback.muted,
                  onChanged: (_) => feedback.toggleMuted(),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Licenses'),
                  onTap: () => showLicensePage(context: context, applicationName: 'BluJem'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              children: [
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: p.warning),
                  title: Text(
                    'Sign out',
                    style: TextStyle(color: p.warning, fontWeight: FontWeight.w600),
                  ),
                  onTap: () => auth.signOut(),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Other players see your leaderboard name and your About me — never your email, unless you write it there.',
                style: TextStyle(color: p.inkFaint, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeUsername(BuildContext context, String current) async {
    final controller = TextEditingController(text: current);
    final auth = context.read<AuthRepository>();
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Leaderboard name'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(helperText: '3–16 letters, numbers or underscores.', errorText: error),
            onChanged: (_) => setState(() => error = null),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ListenableBuilder(
              listenable: auth,
              builder: (_, _) => FilledButton(
                onPressed: auth.busy
                    ? null
                    : () async {
                        final problem = await auth.changeUsername(controller.text);
                        if (!context.mounted) return;
                        if (problem == null) {
                          Navigator.pop(context, true);
                        } else {
                          setState(() => error = problem);
                        }
                      },
                child: Text(auth.busy ? 'Saving…' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("You're now ${auth.account?.username} on the leaderboard.")));
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    ),
  );
}

/// "About me": a few lines other players see when they tap this player on
/// the leaderboard.
class _AboutTile extends StatefulWidget {
  const _AboutTile();

  @override
  State<_AboutTile> createState() => _AboutTileState();
}

class _AboutTileState extends State<_AboutTile> {
  String? _about;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await context.read<ProfileService>().load();
    if (!mounted) return;
    setState(() {
      _about = profile?.about;
      _failed = profile == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final about = _about;
    return ListTile(
      leading: const Icon(Icons.badge_outlined),
      title: const Text('About me'),
      subtitle: Text(
        _failed
            ? "Couldn't load — tap to try again"
            : about == null
            ? 'Loading…'
            : about.isEmpty
            ? 'Add a few lines for other players: name, hobbies, how to reach you'
            : about,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: about == null || about.isEmpty ? p.inkFaint : p.inkSoft),
      ),
      trailing: const Icon(Icons.edit_outlined),
      onTap: _failed ? _load : (about == null ? null : () => _edit(about)),
    );
  }

  Future<void> _edit(String current) async {
    final service = context.read<ProfileService>();
    final controller = TextEditingController(text: current);
    String? error;
    var saving = false;
    final saved = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('About me'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                maxLength: ProfileService.maxAbout,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: 'Name, about me, hobbies, phone or email…',
                  errorText: error,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Everyone signed in to BluJem can read this when they tap your name on the leaderboard. '
                "Share only what you're happy to make public.",
                style: TextStyle(color: context.palette.inkSoft, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setState(() => saving = true);
                      try {
                        final text = await service.saveAbout(controller.text);
                        if (context.mounted) Navigator.pop(context, text);
                      } on ApiException catch (e) {
                        setState(() {
                          saving = false;
                          error = e.message;
                        });
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
    if (saved != null && mounted) setState(() => _about = saved);
  }
}
