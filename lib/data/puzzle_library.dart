import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/dates.dart';
import '../core/slots.dart';
import '../models/puzzle.dart';
import 'api_client.dart';
import 'local_store.dart';

/// Which sheet the day's slot holds.
enum DayKind {
  /// Today's own published sheet.
  today,

  /// Today's isn't published yet; the latest earlier one stands in.
  standIn,

  /// Nothing published at all yet: a bundled sample, not playable as today.
  awaiting,
}

/// Every sheet the player can open: those an admin published (cached on the
/// device after the first download) and three bundled samples.
///
/// Published and bundled sheets are kept in separate lists so "is today's
/// published?" never has to guess which is which.
class PuzzleLibrary extends ChangeNotifier {
  PuzzleLibrary(this._api, this._store, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final ApiClient _api;
  final LocalStore _store;
  final DateTime Function() _clock;

  static const _cacheKey = 'publishedPuzzles';
  static const _takenDownKey = 'takenDownPuzzles';
  static const _parallelDownloads = 4;

  List<Puzzle> _bundled = const [];
  List<Puzzle> _published = const [];
  List<Puzzle> _takenDown = const [];

  /// True once the server has been asked at least once, either way.
  bool _checked = false;
  bool get checked => _checked;

  bool _syncing = false;
  bool get syncing => _syncing;

  /// Puzzles out now (their slot's time has come) newest first, then the
  /// bundled samples.
  List<Puzzle> get all => [...available, ..._bundled];

  /// Every published sheet the server listed, newest first — for an admin
  /// that includes ones whose time has not come yet.
  List<Puzzle> get published => _published;

  /// The published puzzles whose slot's time has come, newest first. One
  /// that opened on publishing counts a little early, so a phone whose clock
  /// runs behind the server's still shows it when the notification arrives.
  List<Puzzle> get available {
    final now = _clock().toUtc();
    return _published
        .where((p) => !p.releasedAt.isAfter(p.slotKind.opensOnPublish ? now.add(const Duration(minutes: 2)) : now))
        .toList();
  }

  /// Sheets an admin unpublished on this phone, newest first, so they can be
  /// published again: the server lists only published ones.
  List<Puzzle> get takenDown {
    final live = {for (final p in _published) p.id};
    return _takenDown.where((p) => !live.contains(p.id)).toList();
  }

  /// Remembers [puzzle] as unpublished; republishing forgets it again.
  void rememberTakenDown(Puzzle puzzle) {
    _takenDown = _sorted([puzzle, ..._takenDown.where((p) => p.id != puzzle.id)]);
    _saveTakenDown();
  }

  void forgetTakenDown(String id) {
    _takenDown = _takenDown.where((p) => p.id != id).toList();
    _saveTakenDown();
  }

  void _saveTakenDown() {
    _store.writeJson(_takenDownKey, {
      'puzzles': [for (final p in _takenDown) p.toJson()],
    });
    notifyListeners();
  }

  Future<void> load() async {
    final bundled = jsonDecode(await rootBundle.loadString('assets/bundled/puzzles.json'));
    _bundled = [for (final p in bundled['puzzles'] as List) Puzzle.fromJson(Map<String, dynamic>.from(p))];
    final cached = _store.readJson(_cacheKey)?['puzzles'] as List?;
    _published = _sorted(
      [for (final p in cached ?? const []) Puzzle.fromJson(Map<String, dynamic>.from(p as Map))]
          .where((p) => p.image.isAsset || File(p.image.path).existsSync()),
    );
    final down = _store.readJson(_takenDownKey)?['puzzles'] as List?;
    _takenDown = _sorted([for (final p in down ?? const []) Puzzle.fromJson(Map<String, dynamic>.from(p as Map))]);
    _scheduleNextSlot();
    notifyListeners();
  }

  /// For tests: the library with these sheets and no files.
  @visibleForTesting
  void debugSet({
    List<Puzzle> published = const [],
    List<Puzzle> bundled = const [],
    List<Puzzle> takenDown = const [],
    bool checked = true,
  }) {
    _published = _sorted(published);
    _takenDown = _sorted(takenDown);
    _bundled = bundled;
    _checked = checked;
    notifyListeners();
  }

  // ------------------------------------------------------------- the day

  /// The puzzle day is India's, wherever the phone is.
  String get _today => indiaDate(_clock());

  /// Today's puzzles that are out, in slot order (morning, afternoon, night).
  List<Puzzle> get todaysPuzzles => available.where((p) => p.publishDate == _today).toList().reversed.toList();

  /// Today's fixed-time slots still to come (afternoon, night), with when each
  /// opens. The morning and Sunday ones have no time to wait for: they open
  /// when the admin publishes them.
  List<(Slot, DateTime)> get upcomingToday {
    final now = _clock().toUtc();
    return [
      for (final slot in Slot.forDate(_today))
        if (!slot.opensOnPublish && slotStart(_today, slot).isAfter(now)) (slot, slotStart(_today, slot)),
    ];
  }

  Timer? _nextSlot;

  /// Wakes the app when the next slot opens — today's afternoon or night, or tomorrow's
  /// first — so its puzzle appears without the player doing anything.
  void _scheduleNextSlot() {
    _nextSlot?.cancel();
    final now = _clock().toUtc();
    final tomorrow = indiaDate(now.add(const Duration(days: 1)));
    final next = [
      for (final day in [_today, tomorrow])
        for (final slot in Slot.forDate(day)) slotStart(day, slot),
    ].where((t) => t.isAfter(now)).firstOrNull;
    if (next == null) return;
    // A few seconds late, so the server agrees the slot has opened.
    _nextSlot = Timer(next.difference(now) + const Duration(seconds: 5), () {
      notifyListeners();
      unawaited(sync());
      _scheduleNextSlot();
    });
  }

  /// The app is on screen again after time in the background, where phones
  /// pause the slot timer: catch up at once — a new day, or a 3 PM or 9 PM
  /// puzzle that opened meanwhile — and set the timer again.
  void onResumed() {
    _scheduleNextSlot();
    notifyListeners();
    unawaited(sync());
  }

  @override
  void dispose() {
    _nextSlot?.cancel();
    super.dispose();
  }

  /// A fixed-time slot of today's has opened but its puzzle has not reached the
  /// phone. A morning one not here yet is simply not published: its
  /// notification says when it is.
  bool get missingOpenedSlot {
    final now = _clock().toUtc();
    final here = {for (final p in todaysPuzzles) p.slotKind};
    return Slot.forDate(_today)
        .any((s) => !s.opensOnPublish && !slotStart(_today, s).isAfter(now) && !here.contains(s));
  }

  /// The newest of today's puzzles that are out: the night one once it is.
  Puzzle? get todaysSheet => todaysPuzzles.lastOrNull;

  /// The latest published sheet from before today, usually yesterday's night one.
  Puzzle? get latestBeforeToday => available.where((p) => p.publishDate.compareTo(_today) < 0).firstOrNull;

  DayKind get dayKind => todaysSheet != null
      ? DayKind.today
      : latestBeforeToday != null
      ? DayKind.standIn
      : DayKind.awaiting;

  /// The sheet the day's slot holds: today's, else the stand-in, else a
  /// rotating bundled sample behind the "not here yet" notice.
  Puzzle get dayPuzzle =>
      todaysSheet ??
      latestBeforeToday ??
      (_bundled.isEmpty ? _published.first : _bundled[_clock().dayOfYear % _bundled.length]);

  /// "yesterday's" or "October 21's", for the stand-in notice.
  String standInDayName() {
    final day = latestBeforeToday?.day;
    if (day == null) return "the last";
    return isSameDay(day, _clock().subtract(const Duration(days: 1))) ? "yesterday's" : "${monthDay(day)}'s";
  }

  Puzzle? byId(String id) => all.where((p) => p.id == id).firstOrNull;

  /// The sheet published for [day], if any (its first slot's, when it has two).
  Puzzle? forDay(DateTime day) => [..._published, ..._bundled].where((p) => p.publishDate == isoDate(day)).lastOrNull;

  /// The sheet published for [slot] on [day], if any.
  Puzzle? forSlot(DateTime day, Slot slot) =>
      _published.where((p) => p.publishDate == isoDate(day) && p.slotKind == slot).firstOrNull;

  // ------------------------------------------------------------- syncing

  /// Brings down every published sheet. Today's first, on its own, so the
  /// player is not kept waiting behind the archive. Silent on failure: what is
  /// cached and bundled still plays.
  Future<void> sync() async {
    if (_syncing) return;
    _syncing = true;
    notifyListeners();
    try {
      // client 2: this app checks answers by hash, so the server sends no answers.
      final reply = await _api.tryPost(JumbleFunction.data, 'puzzles/list', body: {'client': 2});
      final rows = reply?['puzzles'] as List?;
      if (rows == null) return;

      final listed = <(Puzzle, String)>[];
      for (final row in rows.whereType<Map>()) {
        try {
          final p = Puzzle.fromJson(Map<String, dynamic>.from(row));
          final key = '${row['sheetKey'] ?? ''}';
          if (key.isNotEmpty && p.published && p.isPlayable) listed.add((p, key));
        } catch (e) {
          debugPrint('Skipping a malformed puzzle: $e');
        }
      }

      final today = listed.where((e) => e.$1.publishDate == _today).toList();
      final rest = listed.where((e) => e.$1.publishDate != _today).toList();
      final fetched = <Puzzle>[...await _withImages(today)];
      _checked = true;
      // Today's sheet goes live now; the rest follows when it has downloaded.
      _publish(
        {
          for (final p in [..._published, ...fetched]) p.id: p,
        }.values,
        live: listed,
      );
      fetched.addAll(await _withImages(rest));
      _publish(fetched, live: listed);
    } finally {
      _checked = true;
      _syncing = false;
      notifyListeners();
    }
  }

  /// Keeps the sheets still listed by the server — an unpublished one goes —
  /// and writes them to the cache.
  void _publish(Iterable<Puzzle> sheets, {required List<(Puzzle, String)> live}) {
    final ids = {for (final e in live) e.$1.id};
    _published = _sorted(sheets.where((p) => ids.contains(p.id)));
    _store.writeJson(_cacheKey, {
      'puzzles': [for (final p in _published) p.toJson()],
    });
    notifyListeners();
  }

  Future<List<Puzzle>> _withImages(List<(Puzzle, String)> listed) async {
    final out = <Puzzle>[];
    for (var i = 0; i < listed.length; i += _parallelDownloads) {
      final batch = listed.skip(i).take(_parallelDownloads);
      final done = await Future.wait(batch.map((e) => _withImage(e.$1, e.$2)));
      out.addAll(done.whereType<Puzzle>());
    }
    return out;
  }

  /// Downloads a sheet image once and keeps it after.
  Future<Puzzle?> _withImage(Puzzle puzzle, String key) async {
    // Cartoons uploaded per slot are all called cartoon.png on the server, so
    // each is kept under its puzzle's id; the -cartoon name marks it as one.
    // An edit can replace a slot's cartoon under the same key: its version, in
    // the name, makes that a new file to fetch. (Other keys are never reused.)
    final name = key.startsWith('puzzles/')
        ? '${puzzle.id}${_versionTag(puzzle)}-cartoon.${key.split('.').last}'
        : key.split('/').last;
    final file = File('${_store.folder('sheets').path}/$name');
    if (!(file.existsSync() && file.lengthSync() > 0)) {
      final ok = await _api.download(JumbleFunction.data, 'puzzles/sheet', {'key': key}, file);
      if (!ok) {
        // An edited puzzle whose new picture did not come down this time
        // keeps the picture already here, rather than leaving the list
        // (and History) until the next sync.
        final kept = _published.where((p) => p.id == puzzle.id && !p.image.isAsset).firstOrNull?.image;
        if (kept != null && File(kept.path).existsSync()) return puzzle.withImage(kept);
        return null;
      }
    }
    return puzzle.withImage(SheetImage.file(file.path));
  }

  /// [puzzle]'s wordless cartoon for the share card, downloaded once and kept;
  /// null when it has none (or it could not be fetched just now).
  Future<File?> wordlessImage(Puzzle puzzle) async {
    final key = puzzle.wordlessKey;
    if (key.isEmpty) return null;
    final file = File('${_store.folder('sheets').path}/${puzzle.id}${_versionTag(puzzle)}-wordless.png');
    if (file.existsSync() && file.lengthSync() > 0) return file;
    final ok = await _api.download(JumbleFunction.data, 'puzzles/sheet', {'key': key}, file);
    return ok ? file : null;
  }

  /// "-k3x9" from the puzzle's [Puzzle.sheetVersion], or '' when it has none.
  static String _versionTag(Puzzle puzzle) {
    final v = puzzle.sheetVersion.trim();
    if (v.isEmpty) return '';
    final hash = v.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) & 0x7fffffff);
    return '-${hash.toRadixString(36)}';
  }

  /// Newest first: by date, and on one date the later slot first.
  static List<Puzzle> _sorted(Iterable<Puzzle> puzzles) => [...puzzles]
    ..sort((a, b) {
      final byDate = b.publishDate.compareTo(a.publishDate);
      return byDate != 0 ? byDate : b.releasedAt.compareTo(a.releasedAt);
    });
}
