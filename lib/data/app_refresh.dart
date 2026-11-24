import 'dart:async';

import 'package:flutter/widgets.dart';

/// Keeps the app fresh the way other apps are: whenever it comes back to the
/// screen, and every few minutes while it stays open, everything it shows is
/// read again — puzzles, the player's record and profile — and screens that
/// listen (the leaderboard) reload too. Nobody has to pull down to refresh.
class AppRefresh extends ChangeNotifier with WidgetsBindingObserver {
  AppRefresh(this._refresh, {DateTime Function()? clock, this.every = const Duration(minutes: 5)})
    : _clock = clock ?? DateTime.now;

  /// Reads everything again.
  final VoidCallback _refresh;
  final DateTime Function() _clock;

  /// How often to refresh while the app stays on screen.
  final Duration every;

  /// A refresh this soon after the last one is skipped (a share sheet or a
  /// permission prompt also counts as leaving the app and coming back).
  static const _minGap = Duration(seconds: 15);

  Timer? _timer;
  DateTime? _last;

  /// Starts listening for the app coming back, and the regular refresh.
  void start() {
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        refreshNow();
        _startTimer();
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        // No refreshing in the background; it catches up on the way back.
        _timer?.cancel();
      default:
        break;
    }
  }

  /// Refreshes, unless it just did.
  void refreshNow() {
    final now = _clock();
    if (_last != null && now.difference(_last!) < _minGap) return;
    _last = now;
    _refresh();
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => refreshNow());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
