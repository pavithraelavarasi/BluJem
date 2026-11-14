import 'package:blujem/models/records.dart';
import 'package:flutter_test/flutter_test.dart';

/// Today's medal: one per puzzle solved, up to Gold.
void main() {
  test('no medal before the first puzzle', () => expect(medalFor(0), isNull));
  test('1 Bronze, 2 Silver, 3 Gold', () {
    expect(medalFor(1), '🥉 Bronze');
    expect(medalFor(2), '🥈 Silver');
    expect(medalFor(3), '🥇 Gold');
  });

  test("Sunday's one Mega Jumble is Gold", () => expect(medalFor(1, ofDay: 1), '🥇 Gold'));
}
