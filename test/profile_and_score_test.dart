import 'package:blujem/data/profile_service.dart';
import 'package:blujem/models/records.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a late solve carries the half it lost', () {
    final score = PuzzleScore.fromJson({
      'wordPoints': 50,
      'finalAnswerPoints': 30,
      'timeBonus': 80,
      'multiplier': 2,
      'latePenalty': 80,
      'totalPoints': 80,
    });
    expect(score.latePenalty, 80);
    expect(score.wordPoints + score.finalAnswerPoints + score.timeBonus - score.latePenalty, score.totalPoints);
    // From a server before the rule: nothing taken off.
    expect(PuzzleScore.fromJson({'totalPoints': 10}).latePenalty, 0);
  });

  test('a profile without a name or About me reads as an empty Player', () {
    final profile = PlayerProfile.fromJson({'about': null});
    expect(profile.name, 'Player');
    expect(profile.about, '');
    expect(profile.you, isFalse);
    expect(
      PlayerProfile.fromJson({'name': 'Arkay', 'about': 'Chennai · crosswords', 'you': true}).about,
      'Chennai · crosswords',
    );
  });
}
