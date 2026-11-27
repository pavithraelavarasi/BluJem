import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_updates.dart';
import '../data/auth_repository.dart';
import '../game/game_controller.dart';
import '../models/puzzle.dart';
import 'screens/admin_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/play_screen.dart';
import 'screens/profile_screen.dart';
import 'theme.dart';

class BluJemApp extends StatelessWidget {
  const BluJemApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BluJem',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(Brightness.light),
    // Always light: the sheet is a newspaper page, and the board is
    // designed for paper, not for a phone set to dark mode.
    themeMode: ThemeMode.light,
    home: const _Gate(),
  );
}

/// Sign-in first: the game only exists once there is an account behind it.
/// Signing in or out also swaps whose game and record are on the device.
class _Gate extends StatefulWidget {
  const _Gate();

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  @override
  Widget build(BuildContext context) {
    final account = context.select<AuthRepository, String?>((a) => a.account?.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<GameController>().onAccountChanged(account);
    });
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: account == null ? const AuthScreen() : _Shell(key: ValueKey(account)),
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell({super.key});

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _tab = 0;
  final _leaderboard = GlobalKey<LeaderboardScreenState>();

  static const _destinations = [
    (Icons.home_outlined, Icons.home_rounded, 'Today'),
    (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'History'),
    (Icons.leaderboard_outlined, Icons.leaderboard_rounded, 'Ranks'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  /// Admins also get the puzzle upload.
  static const _admin = (Icons.upload_outlined, Icons.upload_rounded, 'Upload');

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  /// Offers a newer published version, once per launch.
  Future<void> _checkForUpdate() async {
    final updates = context.read<AppUpdates>();
    final release = await updates.newer();
    if (release == null || !mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateDialog(updates: updates, release: release),
    );
  }

  void _select(int tab) {
    setState(() => _tab = tab);
    if (tab == 2) _leaderboard.currentState?.refresh();
  }

  Future<void> _play({Puzzle? puzzle}) async {
    final game = context.read<GameController>();
    puzzle == null ? game.openToday() : game.openPuzzle(puzzle);
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => PlayScreen(onOpenLeaderboard: () => _select(2))));
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.select<AuthRepository, bool>((a) => a.account?.isAdmin ?? false);
    final pages = [
      HomeScreen(
        onPlayToday: _play,
        onOpen: (p) => _play(puzzle: p),
      ),
      HistoryScreen(onOpen: (p) => _play(puzzle: p)),
      LeaderboardScreen(key: _leaderboard),
      const ProfileScreen(),
      if (admin) const AdminScreen(),
    ];
    final destinations = [..._destinations, if (admin) _admin];
    final body = IndexedStack(index: _tab.clamp(0, pages.length - 1), children: pages);
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final p = context.palette;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _tab.clamp(0, pages.length - 1),
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Image.asset('assets/images/blujem_logo.png', width: 72, semanticLabel: 'BluJem'),
              ),
              destinations: [
                for (final (icon, selected, label) in destinations)
                  NavigationRailDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: Text(label)),
              ],
            ),
            VerticalDivider(width: 1, color: p.rule),
            Expanded(
              child: Center(
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: body),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.clamp(0, pages.length - 1),
        onDestinationSelected: _select,
        destinations: [
          for (final (icon, selected, label) in destinations)
            NavigationDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: label),
        ],
      ),
    );
  }
}

/// A newer version is out: what changed, and the download straight into
/// Android's installer.
class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.updates, required this.release});

  final AppUpdates updates;
  final AppRelease release;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress;
  String? _error;

  Future<void> _update() async {
    setState(() {
      _progress = 0;
      _error = null;
    });
    final apk = await widget.updates.download(widget.release, (p) {
      if (mounted) setState(() => _progress = p);
    });
    if (!mounted) return;
    if (apk == null) {
      setState(() {
        _progress = null;
        _error = 'The download did not finish. Check your connection and try again.';
      });
      return;
    }
    await widget.updates.install(apk);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final release = widget.release;
    final downloading = _progress != null;
    return AlertDialog(
      title: Text('BluJem ${release.versionName} is here'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(release.notes.isNotEmpty ? release.notes : 'A new version is ready to install.'),
          if (downloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress == 0 ? null : _progress),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: context.palette.warning)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: downloading ? null : () => Navigator.of(context).pop(), child: const Text('Later')),
        FilledButton(onPressed: downloading ? null : _update, child: Text(downloading ? 'Downloading…' : 'Update')),
      ],
    );
  }
}
