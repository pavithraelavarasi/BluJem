import 'package:blujem/game/board.dart';
import 'package:blujem/ui/theme.dart';
import 'package:blujem/ui/widgets/tile_row.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

RowState row(String letters) =>
    RowState(id: 1, answer: letters, pool: letters, order: List.generate(letters.length, (i) => i));

void main() {
  late List<(int, int)> drags;
  late List<int> taps;
  late int misses;
  late PageController pages;

  setUp(() {
    drags = [];
    taps = [];
    misses = 0;
    pages = PageController();
  });

  Widget tileRow(RowState r, List<int> groups) => TileRow(
    row: r,
    color: Colors.pink,
    groups: groups,
    formed: 0,
    enabled: true,
    showCursor: true,
    maxTile: 44,
    onTap: taps.add,
    onDrag: (a, b) => drags.add((a, b)),
    onMiss: () => misses++,
  );

  /// A row on the first page of a pager, as on the Words page.
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        // Android's own touch slop, smaller than Flutter's default: the page
        // swipe picks it up from here, as on a phone.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(gestureSettings: const DeviceGestureSettings(touchSlop: 8)),
          child: child!,
        ),
        home: Scaffold(
          body: PageView(
            controller: pages,
            children: [
              Center(child: child),
              const Center(child: Text('cartoon')),
            ],
          ),
        ),
      ),
    );
  }

  Rect square(WidgetTester tester, int i, TileLayout layout) {
    final origin = tester.getTopLeft(find.byType(TileRow));
    final p = layout.positions[i];
    return Rect.fromLTWH(origin.dx + p.dx, origin.dy + p.dy, layout.size, layout.size);
  }

  testWidgets('a drag that starts on a letter moves it and never turns the page', (tester) async {
    await pump(tester, tileRow(row('RAJA'), [4]));
    final layout = TileLayout.of([4], 400, maxSize: 44);
    await tester.dragFrom(square(tester, 0, layout).center, Offset(layout.size * 3.2, 0));
    await tester.pump(const Duration(milliseconds: 600));
    expect(drags, [(0, 3)]);
    expect(pages.page, 0);
  });

  testWidgets('a swipe that starts beside the letters turns the page', (tester) async {
    await pump(tester, tileRow(row('RAJA'), [4]));
    await tester.dragFrom(const Offset(390, 400), const Offset(-300, 0));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(drags, isEmpty);
    expect(pages.page, 1);
  });

  testWidgets('a letter can be dragged to the other line of a wrapped answer', (tester) async {
    final groups = [5, 5, 4];
    await pump(tester, tileRow(row('ABCDEFGHIJKLMN'), groups));
    final layout = TileLayout.of(groups, 400, maxSize: 44);
    expect(layout.positions.last.dy, greaterThan(0), reason: 'the answer wraps');
    final last = layout.positions.length - 1;
    final from = square(tester, 0, layout).center;
    final to = square(tester, last, layout).center;
    final gesture = await tester.startGesture(from);
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 600));
    expect(drags, [(0, last)]);
  });

  testWidgets('a tap beside the letters picks the row without moving one', (tester) async {
    await pump(tester, tileRow(row('RAJA'), [4]));
    await tester.tapAt(const Offset(390, 400));
    await tester.pump();
    expect(drags, isEmpty);
    expect(misses, 1);
  });

  testWidgets('tapping a letter forms it; a drag never counts as a tap', (tester) async {
    await pump(tester, tileRow(row('RAJA'), [4]));
    final layout = TileLayout.of([4], 400, maxSize: 44);
    await tester.tapAt(square(tester, 1, layout).center);
    await tester.pump(const Duration(milliseconds: 200));
    expect(taps, [1]);
    expect(drags, isEmpty);
    await tester.dragFrom(square(tester, 3, layout).center, Offset(-layout.size * 3.2, 0));
    await tester.pump(const Duration(milliseconds: 600));
    expect(taps, [1]);
    expect(drags, [(3, 0)]);
  });

  /// Small steps from square [from] to square [to], drifting [slant] down per
  /// unit across, as a real finger does.
  Future<void> slowDrag(WidgetTester tester, Offset from, Offset to, {double slant = 0}) async {
    final gesture = await tester.startGesture(from);
    const steps = 30;
    final step = (to - from) / steps.toDouble();
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(step + Offset(0, step.dx.abs() * slant));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('every letter of a word can be dragged, even on a slant inside a scrolling page', (tester) async {
    final groups = [6];
    await pump(
      tester,
      SingleChildScrollView(
        child: Column(
          children: [const SizedBox(height: 300), tileRow(row('AOTOTT'), groups), const SizedBox(height: 900)],
        ),
      ),
    );
    final layout = TileLayout.of(groups, 400, maxSize: 44);
    for (var i = 0; i < 6; i++) {
      final to = (i + 3) % 6;
      await slowDrag(tester, square(tester, i, layout).center, square(tester, to, layout).center, slant: 0.25);
      expect(drags.last, (i, to), reason: 'letter ${i + 1}');
    }
    expect(pages.page, 0);
  });

  testWidgets('the final answer takes a letter into an empty square by drag or by taps', (tester) async {
    final groups = [3, 3];
    final answer = RowState(id: 9, answer: 'ABCDEF', pool: 'AB CD ', order: List.generate(6, (i) => i));
    await pump(tester, tileRow(answer, groups));
    final layout = TileLayout.of(groups, 400, maxSize: 44);
    await slowDrag(tester, square(tester, 0, layout).center, square(tester, 5, layout).center);
    expect(drags.last, (0, 5));
    await tester.tapAt(square(tester, 3, layout).center);
    await tester.pump(const Duration(milliseconds: 200));
    expect(taps, [3]);
    await tester.tapAt(square(tester, 2, layout).center);
    await tester.pump(const Duration(milliseconds: 200));
    expect(taps, [3], reason: 'an empty square is not a letter to tap');
  });

  test('words of different lengths share one square size', () {
    final five = TileLayout.of([5], 300, sizeFor: 7);
    final seven = TileLayout.of([7], 300, sizeFor: 7);
    expect(five.size, seven.size);
    expect(TileLayout.of([5], 300).size, greaterThan(seven.size), reason: 'without it the shorter word is bigger');
  });

  testWidgets('a shake jiggles an unsolved word, then it settles; a solved word stays still', (tester) async {
    double offsetOf() {
      final t = tester.widget<Transform>(
        find.descendant(of: find.byType(TileRow), matching: find.byType(Transform)).first,
      );
      return t.transform.getTranslation().x;
    }

    Widget rowWith(RowState r, int tick) => TileRow(
      row: r,
      color: Colors.pink,
      groups: const [4],
      formed: 0,
      enabled: true,
      showCursor: false,
      onTap: (_) {},
      onDrag: (_, _) {},
      shuffleTick: tick,
    );

    await pump(tester, rowWith(row('RAJA'), 0));
    expect(offsetOf(), 0);
    await pump(tester, rowWith(row('ARJA'), 1));
    await tester.pump(const Duration(milliseconds: 40));
    expect(offsetOf().abs(), greaterThan(0), reason: 'the word jiggles');
    await tester.pump(const Duration(milliseconds: 600));
    expect(offsetOf(), 0, reason: 'and settles');

    final solved = RowState(id: 1, answer: 'AJAR', pool: 'AJAR', order: const [0, 1, 2, 3], solved: true);
    await pump(tester, rowWith(solved, 1));
    await pump(tester, rowWith(solved, 2));
    await tester.pump(const Duration(milliseconds: 40));
    expect(offsetOf(), 0, reason: 'a solved word does not move');
  });
}
