import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/box_rect.dart';

/// A collage with its answer row added underneath.
typedef BuiltSheet = ({Uint8List png, double aspectRatio, List<List<BoxRect>> words, List<BoxRect> finalBoxes});

/// Adds the answer row the collage does not have: a white strip below it with
/// a square and circle for every letter of the answer, grouped as [groups],
/// the way a printed row looks. Every word square moves up to match the
/// taller image. Runs in the background.
Future<BuiltSheet> buildSheet(Uint8List collage, List<List<BoxRect>> words, List<int> groups) =>
    Isolate.run(() => _build(collage, words, groups));

BuiltSheet _build(Uint8List collage, List<List<BoxRect>> words, List<int> groups) {
  final source = img.decodeImage(collage);
  if (source == null) throw const FormatException('The collage could not be read.');
  final cells = words.expand((w) => w).toList();
  if (cells.isEmpty) throw const FormatException('The collage has no squares.');
  double median(Iterable<double> v) => (v.toList()..sort())[cells.length ~/ 2];
  final cellW = median(cells.map((c) => c.w));
  final cellH = median(cells.map((c) => c.h));

  // Room for one row of squares with a margin above and below.
  final strip = max(40, (cellH * source.height * 2.2).round());
  final sheet = img.Image(width: source.width, height: source.height + strip, numChannels: 3);
  img.fill(sheet, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(sheet, source);

  final scale = source.height / sheet.height;
  final moved = [
    for (final w in words) [for (final b in w) BoxRect(b.x, b.y * scale, b.w, b.h * scale, circled: b.circled)],
  ];

  // The answer row, centred in the strip, square for square like the words'.
  final top = scale;
  final w = min(cellW, 0.94 / (groups.fold(0, (a, b) => a + b) + groups.length - 1));
  final h = cellH * scale * (w / cellW);
  final finalBoxes = answerRow(w, groups, top + ((1 - top) - h) / 2, h);

  final ink = img.ColorRgb8(0, 0, 0);
  for (final box in finalBoxes) {
    final l = box.x * sheet.width, r = box.right * sheet.width;
    final t = box.y * sheet.height, b = box.bottom * sheet.height;
    final stroke = max(2, ((r - l) * 0.05).round());
    img.drawRect(sheet, x1: l.round(), y1: t.round(), x2: r.round(), y2: b.round(), color: ink, thickness: stroke);
    final radius = (min(r - l, b - t) / 2 * 0.84).round();
    for (var i = 0; i < max(1, stroke ~/ 2); i++) {
      img.drawCircle(
        sheet,
        x: ((l + r) / 2).round(),
        y: ((t + b) / 2).round(),
        radius: radius - i,
        color: ink,
        antialias: true,
      );
    }
  }
  return (png: img.encodePng(sheet), aspectRatio: sheet.width / sheet.height, words: moved, finalBoxes: finalBoxes);
}

/// Squares for an answer of [groups] letters per word, a square's width
/// apart, centred and never pushed off the page.
List<BoxRect> answerRow(double boxWidth, List<int> groups, double y, double h) {
  final letters = groups.fold(0, (a, b) => a + b);
  if (letters <= 0 || boxWidth <= 0) return const [];
  final total = (letters + max(0, groups.length - 1)) * boxWidth;
  var x = max(0.02, (1 - total) / 2);
  final out = <BoxRect>[];
  for (final size in groups) {
    for (var i = 0; i < size; i++) {
      out.add(BoxRect(x, y, boxWidth, h, circled: true));
      x += boxWidth;
    }
    x += boxWidth;
  }
  return out;
}
