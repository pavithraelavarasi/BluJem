import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/box_rect.dart';
import '../models/puzzle.dart';

/// Where the cartoon is on a sheet: the stored crop when there is one,
/// otherwise found on the image. Runs in a background isolate.
BoxRect locateCartoon((Uint8List, List<List<BoxRect>>, List<BoxRect>, BoxRect?) job) {
  final (bytes, words, finalBoxes, stored) = job;
  if (stored != null) return stored;
  final limit = isBluJemLayout(words) ? cartoonSearchLimit(finalBoxes) : 1.0;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return cartoonPanel(null, limit);

  // A few hundred pixels across is plenty to find a frame, and quick.
  final upperHeight = (decoded.height * limit).round().clamp(1, decoded.height);
  final upper = img.copyCrop(decoded, x: 0, y: 0, width: decoded.width, height: upperHeight);
  final width = min(600, upper.width);
  final small = img.copyResize(upper, width: width);
  final gray = Int32List(small.width * small.height);
  for (final px in small) {
    gray[px.y * small.width + px.x] = ((px.r * 299 + px.g * 587 + px.b * 114) / 1000).round();
  }
  return cartoonPanel(findCartoonFrame(gray, small.width, small.height), limit);
}

/// A BluJem upload: every word square on the left half, so the cartoon is on
/// the right and the answer row runs underneath both.
bool isBluJemLayout(List<List<BoxRect>> words) {
  final boxes = words.expand((w) => w);
  return boxes.isNotEmpty && boxes.every((b) => b.right < 0.5);
}

/// How far down the frame is looked for: to just above the answer row, whose
/// touching squares would otherwise pass for the frame's bottom edge.
double cartoonSearchLimit(List<BoxRect> finalBoxes) =>
    finalBoxes.isEmpty ? 1 : min(1, max(0.3, finalBoxes.map((b) => b.y).reduce(min) - 0.005));

/// The cartoon on the whole sheet, from a frame found in its top [limit] —
/// or, with none found, the right half above the answer row.
BoxRect cartoonPanel(BoxRect? frameInUpper, double limit) => frameInUpper == null
    ? BoxRect(0.5, 0, 0.5, limit)
    : BoxRect(frameInUpper.x, frameInUpper.y * limit, frameInUpper.w, frameInUpper.h * limit);

/// The cartoon's frame on the right half of a greyscale image, as fractions of
/// it. Its top and bottom edges are the only long dark horizontal runs there,
/// so it spans from the first row holding one to the last. Gaps of a couple
/// of pixels are bridged, for scans.
BoxRect? findCartoonFrame(List<int> gray, int width, int height) {
  const dark = 128;
  if (width < 4 || height < 4 || gray.length < width * height) return null;
  final x0 = width ~/ 2;
  final needed = (width - x0) ~/ 2;
  var top = -1, bottom = -1, left = width, right = -1;

  for (var y = 0; y < height; y++) {
    final row = y * width;
    var start = -1, last = -1, gap = 0;
    var bestLength = 0, bestStart = 0, bestEnd = 0;
    void close() {
      if (start >= 0 && last - start + 1 > bestLength) {
        bestLength = last - start + 1;
        bestStart = start;
        bestEnd = last;
      }
      start = -1;
      gap = 0;
    }

    for (var x = x0; x < width; x++) {
      if (gray[row + x] < dark) {
        if (start < 0) start = x;
        last = x;
        gap = 0;
      } else if (start >= 0 && ++gap > 2) {
        close();
      }
    }
    close();
    if (bestLength >= needed) {
      if (top < 0) top = y;
      bottom = y;
      left = min(left, bestStart);
      right = max(right, bestEnd);
    }
  }
  if (top < 0 || bottom - top < height * 0.15) return null;

  const pad = 0.004;
  final l = max(0.0, left / width - pad);
  final t = max(0.0, top / height - pad);
  final r = min(1.0, (right + 1) / width + pad);
  final b = min(1.0, (bottom + 1) / height + pad);
  return BoxRect(l, t, r - l, b - t);
}

/// The job for [locateCartoon], built from [puzzle] and its image bytes.
(Uint8List, List<List<BoxRect>>, List<BoxRect>, BoxRect?) cartoonJob(Puzzle puzzle, Uint8List bytes) => (
  bytes,
  [for (final w in puzzle.words) w.boxes],
  puzzle.finalBoxes,
  puzzle.cartoonOnly ? const BoxRect(0, 0, 1, 1) : puzzle.cartoonCrop,
);
