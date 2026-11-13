import 'dart:io';
import 'dart:ui' as ui;

import 'package:blujem/admin/typed_puzzle.dart';
import 'package:blujem/game/puzzle_page.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TypedPuzzle.parse', () {
    test('reads words, circles, hyphenated squares across lines and the clue', () {
      final p = TypedPuzzle.parse(
        'aDRra\ntuYpT\nhcNRcu\ncRaoCD\n\n'
        "THERE'S NOTHING COMPLICATED ABOUT MAKING BEEF JERKY. THE PROCESS IS ---\n"
        '□□□-□□□-\n□□□\n',
      );
      expect(p.scrambles, ['ADRRA', 'TUYPT', 'HCNRCU', 'CRAOCD']);
      expect(p.circles[0], [false, true, true, false, false]);
      expect(p.circles[3], [false, true, false, false, true, true]);
      expect(p.groups, [3, 3, 3]);
      expect(p.joins, ['-', '-']);
      expect(p.circled, 9);
      expect(p.squares, 9);
      expect(p.clue, startsWith("THERE'S NOTHING"));
    });

    test('a new line or a space between squares splits words', () {
      final p = TypedPuzzle.parse('lwRCa\ndyADd\nfRNOuf\nnYbTOu\n\n□□□□ □□□\n□□□');
      expect(p.groups, [4, 3, 3]);
      expect(p.joins, [' ', ' ']);
      expect(p.circled, 10);
    });

    test('squares can be typed as underscores', () {
      expect(TypedPuzzle.parse('aDRra\ntuYpT\nhcNRcu\ncRaoCD\n___-___-___').groups, [3, 3, 3]);
    });

    test('says what is missing', () {
      expect(() => TypedPuzzle.parse('abc\ndef\n□□'), throwsA(isA<FormatException>()));
      expect(() => TypedPuzzle.parse('aBc\ndEf'), throwsA(isA<FormatException>()));
      expect(() => TypedPuzzle.parse('aBc\n□□\ndEf'), throwsA(isA<FormatException>()));
    });
  });

  test('lays the page out like the server\'s sheets, answer row underneath', () {
    final puzzle = TypedPuzzle.parse('aDRra\ntuYpT\nhcNRcu\ncRaoCD\n\n□□□-□□□-□□□');
    final page = PageLayout(puzzle.scrambles, puzzle.circles, puzzle.groups);
    expect(page.wordBoxes.map((w) => w.length), [5, 5, 6, 6]);
    expect(page.wordBoxes[0].map((b) => b.circled), [false, true, true, false, false]);
    expect(page.wordBoxes.expand((w) => w).every((b) => b.right < 0.5), isTrue, reason: 'words on the left half');
    expect(page.answerBoxes, hasLength(9));
    final top = page.wordBoxes.last.first.bottom;
    expect(page.answerBoxes.every((b) => b.y > top && b.bottom <= 1), isTrue, reason: 'answer row under the page');
  });

  testWidgets('builds the page from the letters and the cartoon', (tester) async {
    final cartoon = img.encodePng(img.fill(img.Image(width: 600, height: 900), color: img.ColorRgb8(200, 60, 60)));
    final puzzle = TypedPuzzle.parse('aDRra\ntuYpT\nhcNRcu\ncRaoCD\n\n□□□-□□□-□□□');
    final key = GlobalKey();
    await tester.pumpWidget(
      Center(
        child: SizedBox(
          width: 900,
          child: RepaintBoundary(
            key: key,
            child: PuzzlePage(layout: PageLayout(puzzle.scrambles, puzzle.circles, puzzle.groups), cartoon: cartoon),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pump();
    expect(find.byType(CustomPaint), findsWidgets);
    final shot = (await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    }))!;
    final page = img.decodePng(shot)!;
    final art = page.getPixel(page.width * 3 ~/ 4, page.height * 2 ~/ 5);
    expect([art.r, art.g, art.b], [200, 60, 60], reason: 'the cartoon on the right');
    final out = Platform.environment['BLUJEM_PAGE_OUT'];
    if (out != null) File(out).writeAsBytesSync(shot);
  });
}
