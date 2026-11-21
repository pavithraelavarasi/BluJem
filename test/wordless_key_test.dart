import 'package:blujem/models/puzzle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the wordless picture sits beside its cartoon, as on the server', () {
    expect(wordlessKeyFor('puzzles/2026-11-22/morning/cartoon.png'), 'puzzles/2026-11-22/morning/cartoon-wordless.png');
    expect(wordlessKeyFor('sheets/abc-cartoon.jpg'), 'sheets/abc-cartoon-wordless.png');
    expect(wordlessKeyFor(''), '');
  });
}
