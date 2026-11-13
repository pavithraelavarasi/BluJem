import 'api_client.dart';

/// A player as others see them: leaderboard name and the "About me" they
/// chose to share.
class PlayerProfile {
  const PlayerProfile({required this.name, required this.about, required this.you});

  final String name;
  final String about;
  final bool you;

  factory PlayerProfile.fromJson(Map<String, dynamic> j) => PlayerProfile(
    name: '${j['name'] ?? ''}'.isEmpty ? 'Player' : '${j['name']}',
    about: '${j['about'] ?? ''}',
    you: j['you'] == true,
  );
}

/// "About me": a few lines a player can share — name, hobbies, how to reach
/// them — for other signed-in players who tap them on the leaderboard.
class ProfileService {
  ProfileService(this._api);

  final ApiClient _api;

  /// The server's limit, checked here too so the field can count down.
  static const maxAbout = 300;

  /// The player behind a leaderboard row, or the signed-in player when [key]
  /// is null. Null when it could not be loaded.
  Future<PlayerProfile?> load({String? key}) async {
    final reply = await _api.tryPost(JumbleFunction.data, 'profile/get', body: {'key': ?key});
    return reply == null ? null : PlayerProfile.fromJson(reply);
  }

  /// Saves the signed-in player's About me; returns what was saved. Throws
  /// [ApiException] with the server's reason when it is refused.
  Future<String> saveAbout(String about) async {
    final reply = await _api.post(JumbleFunction.data, 'profile/about', body: {'about': about});
    return '${reply['about'] ?? ''}';
  }
}
