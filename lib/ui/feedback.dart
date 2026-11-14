import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../data/local_store.dart';
import '../game/game_controller.dart';

/// The game's sounds and haptics, with the player's mute choice remembered,
/// and whether they have found the swipe between Words and Cartoon.
class GameFeedback extends ChangeNotifier {
  GameFeedback(this._store) : _muted = _store.flag(_mutedKey), _pagerLearned = _store.flag(_pagerKey);

  static const _mutedKey = 'muted';
  static const _pagerKey = 'pager_learned';

  /// Page turns before the swipe counts as found and its hint stops nudging.
  static const pagerTurnsToLearn = 3;

  final LocalStore _store;
  final _players = <GameSound, AudioPlayer>{};
  bool _muted;
  bool _pagerLearned;
  int _pageTurns = 0;

  bool get muted => _muted;

  /// The player has turned between Words and Cartoon a few times.
  bool get pagerLearned => _pagerLearned;

  void notePageTurn() {
    if (_pagerLearned || ++_pageTurns < pagerTurnsToLearn) return;
    _pagerLearned = true;
    _store.setFlag(_pagerKey, true);
    notifyListeners();
  }

  /// Every word is in and the answer row is waiting: one light tap.
  void finalReady() => HapticFeedback.lightImpact();

  void toggleMuted() {
    _muted = !_muted;
    _store.setFlag(_mutedKey, _muted);
    notifyListeners();
  }

  /// Each sound's file and volume. The files fade out to silence
  /// (tools/make_sounds.py), so none is heard cut short.
  static const _files = {
    GameSound.key: ('sounds/sfx_key.wav', 0.6),
    GameSound.solved: ('sounds/sfx_solved.wav', 1.0),
    GameSound.complete: ('sounds/sfx_complete.wav', 1.0),
    GameSound.start: ('sounds/sfx_start.wav', 0.9),
    GameSound.shuffle: ('sounds/sfx_shuffle.wav', 0.8),
    GameSound.timeout: ('sounds/sfx_timeout.wav', 0.9),
  };

  /// Loads every sound once, so the first play of each starts at once
  /// rather than being clipped while its file loads. Played alongside the
  /// player's music, never stopping it.
  Future<void> preload() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
    } catch (e) {
      debugPrint('Sound setup: $e');
    }
    for (final sound in GameSound.values) {
      await _player(sound);
    }
  }

  Future<AudioPlayer?> _player(GameSound sound) async {
    final ready = _players[sound];
    if (ready != null) return ready;
    final (file, volume) = _files[sound]!;
    try {
      // The quick tick and swish want the fast path; the longer chimes the
      // full player, which plays them to the end.
      final player = AudioPlayer()
        ..setPlayerMode(
          sound == GameSound.key || sound == GameSound.shuffle ? PlayerMode.lowLatency : PlayerMode.mediaPlayer,
        );
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(volume);
      await player.setSource(AssetSource(file));
      return _players[sound] = player;
    } catch (e) {
      debugPrint('Sound $sound: $e');
      return null;
    }
  }

  void play(GameSound sound) {
    switch (sound) {
      case GameSound.solved:
        HapticFeedback.mediumImpact();
      case GameSound.complete:
        HapticFeedback.heavyImpact();
      default:
        break;
    }
    if (_muted) return;
    unawaited(() async {
      final player = await _player(sound);
      if (player == null) return;
      try {
        // From the top each time: a key tapped fast restarts its tick.
        await player.stop();
        await player.resume();
      } catch (e) {
        debugPrint('Sound $sound: $e');
      }
    }());
  }

  @override
  void dispose() {
    for (final p in _players.values) {
      p.dispose();
    }
    super.dispose();
  }
}

/// The reshuffle buzz: a strong double vibration you notice in the hand.
/// Android drives the vibrator itself (the system haptics are often faint
/// there); iPhone plays two heavy taps.
Future<void> shuffleBuzz() async {
  if (!kIsWeb && Platform.isAndroid) {
    try {
      await const MethodChannel('blujem/haptics').invokeMethod('shuffle');
      return;
    } catch (_) {
      // Fall through to the system haptics.
    }
  }
  await HapticFeedback.heavyImpact();
  await Future<void>.delayed(const Duration(milliseconds: 160));
  await HapticFeedback.heavyImpact();
}

/// Calls back on a firm shake: past 2.4 g, and once per 1.2 s however long
/// the hand keeps going, so one shake is one reshuffle. Phones only, unless
/// [events] is given (tests).
class ShakeDetector {
  ShakeDetector(this.onShake, {this.events, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final VoidCallback onShake;

  /// The accelerometer's readings; the phone's own unless given.
  final Stream<AccelerometerEvent>? events;
  final DateTime Function() _clock;
  StreamSubscription<AccelerometerEvent>? _sub;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  static const force = 2.4;
  static const gap = Duration(milliseconds: 1200);

  static bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  void start() {
    if (_sub != null || (events == null && !supported)) return;
    _sub = (events ?? accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval)).listen((e) {
      final g = sqrt(e.x * e.x + e.y * e.y + e.z * e.z) / 9.80665;
      final now = _clock();
      if (g > force && now.difference(_last) > gap) {
        _last = now;
        onShake();
      }
    }, onError: (Object e) => debugPrint('Shake: $e'));
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
