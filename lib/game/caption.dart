import 'dart:typed_data';

import '../models/box_rect.dart';

/// Where the caption printed under a cartoon begins, as a fraction (0..1) of
/// [region]'s height; null when there is none to find.
///
/// [rgba] is the whole sheet, [width] × [height] pixels, four bytes each, and
/// [region] the cartoon on it. A caption is lines of dark letters on a pale
/// ground — white, cream or a soft tint fading across — with pale rows
/// between the lines and above the first. Reading up from the bottom, past
/// the frame, through text and pale rows, the caption starts at the highest
/// pale row before the picture.
double? captionTop(Uint8List rgba, int width, int height, BoxRect region) {
  final left = (region.x * width).round().clamp(0, width - 1);
  final top = (region.y * height).round().clamp(0, height - 1);
  final w = (region.w * width).round().clamp(1, width - left);
  final h = (region.h * height).round().clamp(1, height - top);
  if (h < 40) return null;

  // The middle of each row: the frame and its rounded corners stay out.
  final x0 = left + (w * 0.06).round();
  final x1 = left + (w * 0.94).round();
  final step = ((x1 - x0) ~/ 240).clamp(1, 1 << 20);

  _Row kind(int y) {
    var pale = 0, ink = 0, n = 0;
    final rowStart = (top + y) * width;
    for (var x = x0; x < x1; x += step) {
      final i = (rowStart + x) * 4;
      final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
      final lo = r < g ? (r < b ? r : b) : (g < b ? g : b);
      final hi = r > g ? (r > b ? r : b) : (g > b ? g : b);
      n++;
      if (lo >= 150 && r * 0.3 + g * 0.59 + b * 0.11 >= 200) {
        pale++;
      } else if (hi - lo <= 45) {
        // Black, or grey where a letter's edge meets the ground.
        ink++;
      }
    }
    if (pale >= 0.95 * n) return _Row.blank;
    if (pale + ink >= 0.92 * n) return _Row.text;
    return _Row.picture;
  }

  // Taller than this, a run of "text" is not one line of a caption.
  final lineMax = h * 0.07;
  var y = h - 1;
  while (y > h * 0.9 && kind(y) == _Row.picture) {
    y--;
  }
  int? start;
  var run = 0;
  for (; y > h * 0.5; y--) {
    final k = kind(y);
    if (k == _Row.blank) {
      start = y;
      run = 0;
    } else if (k == _Row.text) {
      if (++run > lineMax) break;
    } else {
      break;
    }
  }
  return start == null ? null : start / h;
}

enum _Row { blank, text, picture }
