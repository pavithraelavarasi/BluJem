import 'dart:io';

import 'package:blujem/game/caption.dart';
import 'package:blujem/models/box_rect.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Where captionTop finds the caption on a real cartoon, whole image.
double? _find(String path) {
  final image = img.decodeImage(File(path).readAsBytesSync())!.convert(numChannels: 4);
  return captionTop(image.getBytes(order: img.ChannelOrder.rgba), image.width, image.height, const BoxRect(0, 0, 1, 1));
}

void main() {
  test('finds the caption under real cartoons, on white and on a fading tint', () {
    // Measured by eye on each picture: the pale band above the first line.
    expect(_find('images/cartoon-Nov5.png'), closeTo(0.85, 0.02));
    expect(_find('images/cartoon-Nov6.png'), closeTo(0.85, 0.02));
    expect(_find('images/image-Nov 14.png'), closeTo(0.84, 0.02));
    expect(_find('images/image-Nov 14-2.png'), closeTo(0.88, 0.02));
    expect(_find('images/image-Nov 14-3.png'), closeTo(0.83, 0.02));
  }, skip: !File('images/cartoon-Nov5.png').existsSync() ? 'sample cartoons not here' : false);

  test('a picture with no caption keeps all of it', () {
    final image = img.Image(width: 200, height: 300);
    for (final p in image) {
      p
        ..r = (p.x * 7) % 256
        ..g = (p.y * 5) % 256
        ..b = 120;
    }
    final rgba = image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
    expect(captionTop(rgba, 200, 300, const BoxRect(0, 0, 1, 1)), isNull);
  });
}
