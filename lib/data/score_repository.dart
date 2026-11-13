import '../models/records.dart';
import 'api_client.dart';

/// A word as the run ended, for the server to score.
class PlayedWord {
  const PlayedWord(this.letters, {required this.hintsUsed, required this.revealed});
  final String letters;
  final int hintsUsed;
  final bool revealed;
}

/// Points and the leaderboard. Nothing is scored on the device: the server
/// checks what the player did against the answers, its own clock and the
/// hints it handed out, so a score cannot be raised from the phone.
class ScoreRepository {
  ScoreRepository(this._api, this._signedIn);

  final ApiClient _api;
  final bool Function() _signedIn;

  bool get available => _signedIn();

  /// Starts (once) the server's clock for this player on [puzzleId]. Null
  /// when the sheet earns no points: offline, or not a published sheet.
  Future<ScoreStart?> start(String puzzleId, {bool restart = false}) async {
    if (!available) return null;
    final reply = await _api.tryPost(
      JumbleFunction.data,
      'scores/start',
      body: {'puzzleId': puzzleId, 'restart': restart},
    );
    if (reply == null || reply['started'] != true) return null;
    final elapsed = (reply['elapsedSeconds'] as num?)?.toInt() ?? 0;
    return ScoreStart(elapsed < 0 ? 0 : elapsed, alreadyScored: reply['status'] == 'completed');
  }

  Future<PuzzleScore?> submit(
    String puzzleId,
    List<PlayedWord> words,
    String finalLetters, {
    required bool finalRevealed,
  }) async {
    if (!available) return null;
    final reply = await _api.tryPost(
      JumbleFunction.data,
      'scores/submit',
      body: {
        'puzzleId': puzzleId,
        'words': [
          for (final w in words) {'letters': w.letters, 'hintsUsed': w.hintsUsed, 'revealed': w.revealed},
        ],
        'finalLetters': finalLetters,
        'finalRevealed': finalRevealed,
      },
    );
    if (reply == null || reply['scored'] != true) return null;
    return PuzzleScore.fromJson(reply);
  }

  /// A puzzle's answers, which the server keeps until the player has started
  /// it and needs them (a hint, a reveal) or has finished it. Null when it
  /// will not say yet, or cannot be reached.
  Future<({List<String> words, String finalAnswer, String explanation})?> answers(String puzzleId) async {
    if (!available) return null;
    final reply = await _api.tryPost(JumbleFunction.data, 'puzzles/answers', body: {'puzzleId': puzzleId});
    final words = reply?['words'];
    if (reply == null || words is! List) return null;
    return (
      words: [for (final w in words) '$w'.toUpperCase()],
      finalAnswer: '${reply['finalAnswer'] ?? ''}',
      explanation: '${reply['finalExplanation'] ?? ''}',
    );
  }

  Future<ScoreBoard?> leaderboard(ScorePeriod period) async {
    if (!available) return null;
    final reply = await _api.tryPost(JumbleFunction.data, 'scores/leaderboard', body: {'period': period.key});
    return reply == null ? null : ScoreBoard.fromJson(reply);
  }
}
