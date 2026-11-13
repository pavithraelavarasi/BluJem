import 'dart:typed_data';

import 'package:blujem/admin/admin_service.dart';
import 'package:blujem/admin/sheet_builder.dart';
import 'package:blujem/admin/word_index.dart';
import 'package:blujem/models/box_rect.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled word list unscrambles everyday words', () async {
    final index = await WordIndex.load();
    expect(index.unscramble('YRTPA'), contains('PARTY'));
    expect(index.best('YRTPA'), 'PARTY');
    expect(sameLetters('PARTY', 'yrtpa'), isTrue);
    expect(sameLetters('PARTY', 'PARTS'), isFalse);
  });

  test('a prepared day is read from the server reply', () {
    final day = DailyPuzzle.fromJson({
      'date': '2026-10-29',
      'status': 'RENDERED',
      'clue': 'When it rained —',
      'extraction': {
        'words': [
          {'scrambled': 'yrtpa'},
        ],
        'finalAnswer': {
          'groups': [2, 3],
        },
      },
      'layout': {
        'width': 1800,
        'height': 1200,
        'words': [
          [
            {'x': 0.1, 'y': 0.1, 'w': 0.05, 'h': 0.07, 'circled': true},
            {'x': 0.15, 'y': 0.1, 'w': 0.05, 'h': 0.07},
          ],
        ],
      },
      'assets': {'collage-letters.png': 'k'},
      'checks': [
        {'ok': false, 'message': 'Blurry'},
      ],
    })!;
    expect(day.scrambles, ['YRTPA']);
    expect(day.groups, [2, 3]);
    expect(day.squares.single.first.circled, isTrue);
    expect(day.collageAspect, 1.5);
    expect(day.problems, ['Blurry']);
    expect(day.canDraft, isTrue);
  });

  test('the answer row is added under the collage and the words move up', () async {
    final collage = img.encodePng(img.Image(width: 600, height: 400));
    final words = [
      [for (var i = 0; i < 5; i++) BoxRect(0.1 + i * 0.06, 0.5, 0.06, 0.09, circled: i.isEven)],
    ];
    final built = await buildSheet(collage, words, [2, 3]);
    final sheet = img.decodePng(built.png)!;

    expect(sheet.width, 600);
    expect(sheet.height, greaterThan(400));
    expect(built.aspectRatio, closeTo(600 / sheet.height, 1e-9));
    expect(built.finalBoxes, hasLength(5));
    expect(built.finalBoxes.every((b) => b.circled && b.y > 400 / sheet.height && b.bottom <= 1), isTrue);
    // A gap of one square between the two words of the answer.
    expect(built.finalBoxes[2].x - built.finalBoxes[1].right, closeTo(built.finalBoxes[0].w, 1e-9));
    expect(built.words.single.first.y, closeTo(0.5 * 400 / sheet.height, 1e-9));
  });

  test('a Sunday sheet gets its fifteen answer squares, all on the page', () async {
    final collage = Uint8List.fromList(img.encodePng(img.Image(width: 1800, height: 1361)));
    final words = [
      for (var r = 0; r < 6; r++) [for (var i = 0; i < 6; i++) BoxRect(0.02 + i * 0.075, 0.3 + r * 0.11, 0.072, 0.095)],
    ];
    final built = await buildSheet(collage, words, [5, 10]);
    expect(built.words, hasLength(6));
    expect(built.finalBoxes, hasLength(15));
    expect(built.finalBoxes.first.x, greaterThanOrEqualTo(0));
    expect(built.finalBoxes.last.right, lessThanOrEqualTo(1));
  });
}
