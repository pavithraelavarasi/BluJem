import 'package:flutter/foundation.dart';

import '../core/dates.dart';
import '../models/records.dart';
import 'api_client.dart';
import 'local_store.dart';

/// The puzzles this player finished, kept per account on the device and
/// mirrored to the server so History follows them to a new phone.
///
/// The server files every run against the account in the token, never an id
/// sent from here, so one player can never write into another's history.
class RecordsRepository extends ChangeNotifier {
  RecordsRepository(this._api, this._store, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final ApiClient _api;
  final LocalStore _store;
  final DateTime Function() _clock;

  String _owner = 'guest';
  List<Completion> _runs = const [];

  /// Newest first.
  List<Completion> get runs => _runs;

  String get _key => 'completions_$_owner';

  /// Switches to [accountId]'s record, then replaces it with the server's copy.
  Future<void> switchAccount(String? accountId) async {
    _owner = accountId ?? 'guest';
    _runs = _read();
    notifyListeners();
    if (accountId == null) return;
    final reply = await _api.tryPost(JumbleFunction.data, 'completions/list');
    // An empty list is the server's answer too (a fresh account, or scores
    // reset): only a failed call leaves the device's copy as it was.
    final rows = reply?['completions'] as List?;
    if (rows == null) return;
    _write([for (final r in rows.whereType<Map>()) Completion.fromJson(Map<String, dynamic>.from(r))]);
  }

  bool finished(String puzzleId) => _runs.any((r) => r.puzzleId == puzzleId);

  /// The best run kept for [puzzleId], if it has been finished.
  Completion? runOf(String puzzleId) => _runs.where((r) => r.puzzleId == puzzleId).firstOrNull;

  /// Keeps the better run for a puzzle. Only a timed run goes to the server:
  /// the board ranks on the clock, and a run that lost its clock has none.
  Future<void> record(Completion run) async {
    final existing = _runs.where((r) => r.puzzleId == run.puzzleId).firstOrNull;
    final keep = existing == null || run.isBetterThan(existing) ? run : existing;
    _write([..._runs.where((r) => r.puzzleId != run.puzzleId), keep]);
    if (run.timed) {
      await _api.tryPost(
        JumbleFunction.data,
        'completions/record',
        body: {
          'puzzleId': run.puzzleId,
          'sheetDate': run.sheetDate,
          'finalAnswer': run.finalAnswer,
          'seconds': run.seconds,
          'hintsUsed': run.hintsUsed,
          'completedAt': run.completedAt,
        },
      );
    }
  }

  /// Days, on this device's calendar, on which a puzzle was finished.
  Set<DateTime> get solvedDays => {for (final r in _runs) dateOnly(r.completedOn)};

  PlayerStats get stats => statsFor(_runs, _clock());

  /// Profile figures from [runs]; streaks count calendar days ending today or
  /// yesterday, so a streak is only lost once a whole day is missed.
  static PlayerStats statsFor(List<Completion> runs, DateTime now) {
    if (runs.isEmpty) return PlayerStats.empty;
    final timed = [
      for (final r in runs)
        if (r.timed) r.seconds,
    ];
    int epochDay(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;
    final days = {for (final r in runs) epochDay(r.completedOn)}.toList()..sort((a, b) => b - a);
    final today = epochDay(now);

    var current = 0;
    if (days.first >= today - 1) {
      current = 1;
      while (current < days.length && days[current - 1] - days[current] == 1) {
        current++;
      }
    }
    var longest = 1, run = 1;
    for (var i = 1; i < days.length; i++) {
      run = days[i - 1] - days[i] == 1 ? run + 1 : 1;
      if (run > longest) longest = run;
    }

    return PlayerStats(
      currentStreak: current,
      longestStreak: longest,
      puzzlesCompleted: runs.length,
      bestSeconds: timed.isEmpty ? null : timed.reduce((a, b) => a < b ? a : b),
      averageSeconds: timed.isEmpty ? null : (timed.reduce((a, b) => a + b) / timed.length).round(),
      hintsUsed: runs.fold(0, (a, r) => a + r.hintsUsed),
      solvedToday: days.first == today,
    );
  }

  List<Completion> _read() {
    final rows = _store.readJson(_key)?['completed'] as List?;
    return _sorted([for (final r in rows ?? const []) Completion.fromJson(Map<String, dynamic>.from(r as Map))]);
  }

  void _write(List<Completion> runs) {
    _runs = _sorted(runs);
    _store.writeJson(_key, {
      'completed': [for (final r in _runs) r.toJson()],
    });
    notifyListeners();
  }

  static List<Completion> _sorted(List<Completion> runs) =>
      [...runs]..sort((a, b) => b.completedAt.compareTo(a.completedAt));
}
