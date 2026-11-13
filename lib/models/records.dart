/// A signed-in player, as the server describes them.
class Account {
  const Account({
    required this.id,
    required this.email,
    required this.name,
    required this.username,
    required this.role,
    required this.token,
  });

  final String id;
  final String email;
  final String name;

  /// The public handle the leaderboard shows.
  final String username;
  final String role;

  /// Sent as X-Jumble-Token with every backend call.
  final String token;

  bool get isAdmin => role.toLowerCase() == 'admin';

  String get displayName => name.trim().isNotEmpty ? name : email;

  factory Account.fromJson(Map<String, dynamic> user, String token) => Account(
    id: '${user['id'] ?? ''}',
    email: '${user['email'] ?? ''}',
    name: '${user['name'] ?? ''}',
    username: '${user['username'] ?? ''}',
    role: '${user['role'] ?? 'player'}',
    token: token,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'username': username,
    'role': role,
    'token': token,
  };

  static Account? tryParse(Map<String, dynamic>? j) {
    final token = j?['token'];
    if (j == null || token is! String || token.isEmpty) return null;
    return Account.fromJson(j, token);
  }
}

/// One puzzle the player finished.
class Completion {
  const Completion({
    required this.puzzleId,
    required this.sheetDate,
    required this.finalAnswer,
    required this.seconds,
    required this.hintsUsed,
    required this.completedAt,
    this.timed = true,
  });

  final String puzzleId;
  final String sheetDate;
  final String finalAnswer;
  final int seconds;
  final int hintsUsed;

  /// Milliseconds since the epoch.
  final int completedAt;

  /// False when time ran out first: finished, but with no honest time.
  final bool timed;

  DateTime get completedOn => DateTime.fromMillisecondsSinceEpoch(completedAt);

  /// Fewer hints wins, then the faster time; a timed run beats an untimed one.
  bool isBetterThan(Completion other) {
    if (timed != other.timed) return timed;
    if (hintsUsed != other.hintsUsed) return hintsUsed < other.hintsUsed;
    return seconds < other.seconds;
  }

  factory Completion.fromJson(Map<String, dynamic> j) => Completion(
    puzzleId: '${j['puzzleId'] ?? ''}',
    sheetDate: '${j['sheetDate'] ?? ''}',
    finalAnswer: '${j['finalAnswer'] ?? ''}',
    seconds: (j['seconds'] as num?)?.toInt() ?? 0,
    hintsUsed: (j['hintsUsed'] as num?)?.toInt() ?? 0,
    completedAt: (j['completedAt'] as num?)?.toInt() ?? 0,
    timed: j['timed'] != false,
  );

  Map<String, dynamic> toJson() => {
    'puzzleId': puzzleId,
    'sheetDate': sheetDate,
    'finalAnswer': finalAnswer,
    'seconds': seconds,
    'hintsUsed': hintsUsed,
    'completedAt': completedAt,
    'timed': timed,
  };
}

/// The profile's figures, worked out from the runs recorded.
class PlayerStats {
  const PlayerStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.puzzlesCompleted,
    required this.bestSeconds,
    required this.averageSeconds,
    required this.hintsUsed,
    required this.solvedToday,
  });

  final int currentStreak;
  final int longestStreak;
  final int puzzlesCompleted;
  final int? bestSeconds;
  final int? averageSeconds;
  final int hintsUsed;
  final bool solvedToday;

  static const empty = PlayerStats(
    currentStreak: 0,
    longestStreak: 0,
    puzzlesCompleted: 0,
    bestSeconds: null,
    averageSeconds: null,
    hintsUsed: 0,
    solvedToday: false,
  );
}

/// The server's points clock for a run, as it stood when Start was tapped.
class ScoreStart {
  const ScoreStart(this.elapsedSeconds, {required this.alreadyScored});
  final int elapsedSeconds;
  final bool alreadyScored;
}

/// What one finished puzzle earned, as the server worked it out.
class PuzzleScore {
  const PuzzleScore({
    required this.wordPoints,
    required this.finalAnswerPoints,
    required this.basePoints,
    required this.multiplier,
    required this.timeBonus,
    required this.totalPoints,
    required this.rank,
    required this.alreadyScored,
    this.latePenalty = 0,
  });

  final int wordPoints;
  final int finalAnswerPoints;
  final int basePoints;
  final int multiplier;
  final int timeBonus;
  final int totalPoints;
  final int? rank;
  final bool alreadyScored;

  /// The half taken off for solving a puzzle after its day.
  final int latePenalty;

  factory PuzzleScore.fromJson(Map<String, dynamic> j) {
    int n(String k, [int fallback = 0]) => (j[k] as num?)?.toInt() ?? fallback;
    final rank = n('rank');
    return PuzzleScore(
      wordPoints: n('wordPoints'),
      finalAnswerPoints: n('finalAnswerPoints'),
      basePoints: n('basePoints', n('wordPoints') + n('finalAnswerPoints')),
      multiplier: n('multiplier', 1).clamp(1, 5),
      timeBonus: n('timeBonus'),
      totalPoints: n('totalPoints'),
      rank: rank > 0 ? rank : null,
      alreadyScored: j['alreadyScored'] == true,
      latePenalty: n('latePenalty'),
    );
  }
}

/// The speed multiplier, by the same table the server scores with: 5x inside
/// a minute, 4x to 1:30, 3x to 2:00, 2x to 3:00, then 1x.
class Multipliers {
  static const tiers = [(60, 5), (90, 4), (120, 3), (180, 2)];

  static int at(int seconds) {
    for (final (limit, x) in tiers) {
      if (seconds <= limit) return x;
    }
    return 1;
  }

  /// Seconds before the multiplier drops, or null once it is down to 1x.
  static int? secondsLeftAt(int seconds) {
    for (final (limit, _) in tiers) {
      if (seconds <= limit) return limit - seconds;
    }
    return null;
  }
}

enum ScorePeriod {
  today('today', 'Today'),
  week('week', 'This Week'),
  allTime('all', 'All Time');

  const ScorePeriod(this.key, this.label);
  final String key;
  final String label;
}

class ScoreEntry {
  const ScoreEntry({
    required this.rank,
    required this.key,
    required this.name,
    required this.points,
    required this.puzzles,
    required this.you,
  });

  final int rank;
  final String key;
  final String name;
  final int points;
  final int puzzles;
  final bool you;
}

class ScoreBoard {
  const ScoreBoard({required this.entries, required this.myRank, required this.myPoints, required this.myPuzzles});

  final List<ScoreEntry> entries;
  final int? myRank;
  final int myPoints;
  final int myPuzzles;

  factory ScoreBoard.fromJson(Map<String, dynamic> j) {
    final rows = (j['entries'] as List?) ?? const [];
    final me = j['me'] as Map?;
    final myRank = (me?['rank'] as num?)?.toInt() ?? 0;
    return ScoreBoard(
      entries: [
        for (var i = 0; i < rows.length; i++)
          if (rows[i] is Map)
            ScoreEntry(
              rank: (rows[i]['rank'] as num?)?.toInt() ?? i + 1,
              key: '${rows[i]['key'] ?? ''}'.isEmpty ? 'row$i' : '${rows[i]['key']}',
              name: '${rows[i]['name'] ?? ''}'.isEmpty ? 'Player' : '${rows[i]['name']}',
              points: (rows[i]['points'] as num?)?.toInt() ?? 0,
              puzzles: (rows[i]['puzzles'] as num?)?.toInt() ?? 0,
              you: rows[i]['you'] == true,
            ),
      ],
      myRank: myRank > 0 ? myRank : null,
      myPoints: (me?['points'] as num?)?.toInt() ?? 0,
      myPuzzles: (me?['puzzles'] as num?)?.toInt() ?? 0,
    );
  }
}

enum HintSource { ai, offline }

class Hint {
  const Hint(this.text, this.source);
  final String text;
  final HintSource source;
}
