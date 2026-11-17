import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/box_rect.dart';

/// Where everything goes on a BluJem puzzle page — header, word rows, the
/// cartoon on the right and the answer row underneath — in the page's own
/// pixels, the sizes of the sheets the server draws. Nothing is stored as a
/// picture: the page is laid out from the letters whenever it is shown.
class PageLayout {
  PageLayout(this.scrambles, this.circles, this.groups) {
    final longest = scrambles.map((w) => w.length).fold(1, max);
    final natural = longest * _tile + (longest - 1) * _gap;
    final scale = natural > _leftWidth ? _leftWidth / natural : 1.0;
    final pitch = min(_pitch, ((_rowsBottom - _rowsTop) / scrambles.length).floorToDouble());
    tile = min((_tile * scale).floorToDouble(), pitch - _minGap);
    final gap = (_gap * tile / _tile).floorToDouble();
    squares = [
      for (var i = 0; i < scrambles.length; i++)
        () {
          final n = scrambles[i].length;
          final left = (leftCentre - (n * tile + (n - 1) * gap) / 2).roundToDouble();
          return [for (var j = 0; j < n; j++) Rect.fromLTWH(left + j * (tile + gap), _rowsTop + i * pitch, tile, tile)];
        }(),
    ];

    // The answer row, square for square like the words', a square apart
    // between words, centred in a strip under the page.
    final letters = groups.fold(0, (a, b) => a + b);
    if (letters == 0) {
      height = pageHeight;
      answer = const [];
      return;
    }
    final strip = (tile * 2.2).roundToDouble();
    height = pageHeight + strip;
    final size = min(tile, width * 0.94 / (letters + groups.length - 1));
    var x = max(width * 0.02, (width - (letters + groups.length - 1) * size) / 2);
    final y = pageHeight + (strip - size) / 2;
    answer = [];
    for (final n in groups) {
      for (var i = 0; i < n; i++) {
        answer.add(Rect.fromLTWH(x, y, size, size));
        x += size;
      }
      x += size;
    }
  }

  static const width = 1800.0;

  /// The page without its answer row.
  static const pageHeight = 1361.0;
  static const leftCentre = 450.0;
  static const _leftWidth = 840.0;
  static const _rowsTop = 420.0, _rowsBottom = 1326.0, _pitch = 196.0, _minGap = 14.0;
  static const _tile = 130.0, _gap = 12.0;
  static const cartoonBox = Rect.fromLTWH(930, 36, 840, 1290);

  final List<String> scrambles;
  final List<List<bool>> circles;
  final List<int> groups;

  /// Every word square and answer square, in page pixels.
  late final List<List<Rect>> squares;
  late final List<Rect> answer;
  late final double tile;
  late final double height;

  double get aspectRatio => width / height;

  BoxRect _fraction(Rect r, {bool circled = false}) =>
      BoxRect(r.left / width, r.top / height, r.width / width, r.height / height, circled: circled);

  /// The squares as fractions of the page, the way puzzles store them.
  List<List<BoxRect>> get wordBoxes => [
    for (var i = 0; i < squares.length; i++)
      [for (var j = 0; j < squares[i].length; j++) _fraction(squares[i][j], circled: circles[i][j])],
  ];

  List<BoxRect> get answerBoxes => [for (final r in answer) _fraction(r, circled: true)];
}

const _ink = Color(0xFF171717);
const _text = Color(0xFF3C454C);
const _rowFills = [
  Color(0xFFFEC7C8),
  Color(0xFFD0FCD0),
  Color(0xFFC2E4FD),
  Color(0xFFFEFBA6),
  Color(0xFFE6D6FB),
  Color(0xFFFFDDBC),
];
const _numbers = {2: 'two', 3: 'three', 4: 'four', 5: 'five', 6: 'six'};

/// Paints [layout] with its letters, [cartoon] and the BluJem [logo].
class PuzzlePagePainter extends CustomPainter {
  PuzzlePagePainter(this.layout, this.cartoon, this.logo);

  final PageLayout layout;
  final ui.Image cartoon;
  final ui.Image logo;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / PageLayout.width);
    canvas.drawRect(Rect.fromLTWH(0, 0, PageLayout.width, layout.height), Paint()..color = const Color(0xFFFFFFFF));

    // Header: cream box, logo, byline, instructions.
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(32, 35, 836, 336), const Radius.circular(26)),
      Paint()..color = const Color(0xFFFFF9E9),
    );
    const logoHeight = 118.0;
    final logoWidth = logo.width * logoHeight / logo.height;
    _image(canvas, logo, Rect.fromLTWH(PageLayout.leftCentre - logoWidth / 2, 46, logoWidth, logoHeight));
    _centred(canvas, 'By David L Hoyt and Jeff Knurek', 190, 30, FontWeight.w700);
    final count = _numbers[layout.scrambles.length] ?? '${layout.scrambles.length}';
    final instructions = [
      'Unscramble these words, one letter to each square,',
      'to form $count ordinary words.',
      'Then arrange the circled letters to form the surprise',
      'answer, as suggested by the above cartoon.',
    ];
    for (var i = 0; i < instructions.length; i++) {
      _centred(canvas, instructions[i], 246.0 + i * 34, 25, FontWeight.w400);
    }

    // Word rows.
    final k = layout.tile / 130;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * k
      ..color = _ink;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * k
      ..color = _ink;
    for (var i = 0; i < layout.squares.length; i++) {
      for (var j = 0; j < layout.squares[i].length; j++) {
        final square = layout.squares[i][j];
        final shape = RRect.fromRectAndRadius(square, Radius.circular(8 * k));
        canvas.drawRRect(shape, Paint()..color = _rowFills[i % _rowFills.length]);
        canvas.drawRRect(shape, border);
        if (layout.circles[i][j]) canvas.drawCircle(square.center, square.width / 2 - 8 * k, ring);
        final letter = _painter(layout.scrambles[i][j], square.width * 0.62, FontWeight.w700, _ink);
        letter.paint(canvas, square.center - Offset(letter.width / 2, letter.height / 2));
      }
    }

    // Divider and the cartoon, fitted into its box with its proportions kept.
    canvas.drawRect(const Rect.fromLTWH(899, 0, 2, PageLayout.pageHeight), Paint()..color = const Color(0xFF9B9B9B));
    const box = PageLayout.cartoonBox;
    final fit = min(box.width / cartoon.width, box.height / cartoon.height);
    _image(
      canvas,
      cartoon,
      Rect.fromCenter(center: box.center, width: cartoon.width * fit, height: cartoon.height * fit),
    );

    // The answer row: a square with a circle for every letter.
    for (final square in layout.answer) {
      final s = square.width / 130;
      canvas.drawRRect(
        RRect.fromRectAndRadius(square, Radius.circular(8 * s)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * s
          ..color = _ink,
      );
      canvas.drawCircle(
        square.center,
        square.width / 2 - 8 * s,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * s
          ..color = _ink,
      );
    }
  }

  @override
  bool shouldRepaint(PuzzlePagePainter old) => old.layout != layout || old.cartoon != cartoon || old.logo != logo;

  static void _image(Canvas canvas, ui.Image image, Rect to) => canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    to,
    Paint()..filterQuality = FilterQuality.high,
  );

  static TextPainter _painter(String text, double size, FontWeight weight, Color color) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: size, fontWeight: weight, color: color),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  /// [text] centred on the left half with its baseline at [baseline].
  static void _centred(Canvas canvas, String text, double baseline, double size, FontWeight weight) {
    final p = _painter(text, size, weight, _text);
    p.paint(
      canvas,
      Offset(
        PageLayout.leftCentre - p.width / 2,
        baseline - p.computeDistanceToActualBaseline(TextBaseline.alphabetic),
      ),
    );
  }
}

Future<ui.Image>? _logo;

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

/// A puzzle page built from its letters and its cartoon picture.
class PuzzlePage extends StatefulWidget {
  const PuzzlePage({super.key, required this.layout, required this.cartoon});

  final PageLayout layout;

  /// The cartoon picture's bytes, as stored.
  final Uint8List cartoon;

  @override
  State<PuzzlePage> createState() => _PuzzlePageState();
}

class _PuzzlePageState extends State<PuzzlePage> {
  late Future<(ui.Image, ui.Image)> _images = _load();

  Future<(ui.Image, ui.Image)> _load() async {
    final logo = _logo ??= rootBundle
        .load('assets/images/blujem_logo.png')
        .then((d) => _decode(d.buffer.asUint8List()));
    return (await _decode(widget.cartoon), await logo);
  }

  @override
  void didUpdateWidget(PuzzlePage old) {
    super.didUpdateWidget(old);
    if (old.cartoon != widget.cartoon) _images = _load();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: widget.layout.aspectRatio,
    child: FutureBuilder(
      future: _images,
      builder: (context, snap) => snap.data == null
          ? const ColoredBox(
              color: Colors.white,
              child: Center(child: CircularProgressIndicator()),
            )
          : CustomPaint(painter: PuzzlePagePainter(widget.layout, snap.data!.$1, snap.data!.$2)),
    ),
  );
}
