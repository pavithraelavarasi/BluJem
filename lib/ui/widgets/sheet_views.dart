import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/cartoon.dart';
import '../../game/puzzle_page.dart';
import '../../models/box_rect.dart';
import '../../models/puzzle.dart';
import '../theme.dart';

/// A sheet decoded once, with where its cartoon is.
class LoadedSheet {
  const LoadedSheet(this.image, this.cartoon);
  final ui.Image image;
  final BoxRect cartoon;
}

final _cache = <String, Future<LoadedSheet>>{};

/// Loads [puzzle]'s sheet and finds its cartoon, remembered per sheet.
Future<LoadedSheet> loadSheet(Puzzle puzzle) => _cache.putIfAbsent(puzzle.id, () async {
  final bytes = puzzle.image.isAsset
      ? (await rootBundle.load(puzzle.image.path)).buffer.asUint8List()
      : await File(puzzle.image.path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final cartoon = await compute(locateCartoon, cartoonJob(puzzle, bytes));
  return LoadedSheet(frame.image, cartoon);
});

ImageProvider sheetProvider(SheetImage image) =>
    image.isAsset ? AssetImage(image.path) as ImageProvider : FileImage(File(image.path));

/// One region of a sheet, drawn to fill its box.
class SheetCrop extends StatelessWidget {
  const SheetCrop({super.key, required this.image, required this.region});
  final ui.Image image;
  final BoxRect region;

  double get aspect => (region.w * image.width) / (region.h * image.height).clamp(1e-3, double.infinity);

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: aspect,
    child: CustomPaint(painter: _CropPainter(image, region)),
  );
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.image, this.region);
  final ui.Image image;
  final BoxRect region;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      region.x * image.width,
      region.y * image.height,
      region.w * image.width,
      region.h * image.height,
    );
    canvas.drawImageRect(image, src, Offset.zero & size, Paint()..filterQuality = FilterQuality.high);
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.image != image || old.region != region;
}

/// The cartoon, as large as fits; a tap opens it full screen to zoom.
class CartoonView extends StatelessWidget {
  const CartoonView({super.key, required this.puzzle});
  final Puzzle puzzle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FutureBuilder<LoadedSheet>(
      future: loadSheet(puzzle),
      builder: (context, snap) {
        final sheet = snap.data;
        if (sheet == null) {
          return Center(
            child: snap.hasError
                ? Text('The cartoon could not be loaded.', style: TextStyle(color: p.inkSoft))
                : const CircularProgressIndicator(strokeWidth: 2.5),
          );
        }
        return Center(
          child: Semantics(
            button: true,
            label: 'Cartoon. Tap to open full screen',
            child: GestureDetector(
              onTap: () => showZoomable(context, SheetCrop(image: sheet.image, region: sheet.cartoon)),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.rule),
                  color: Colors.white,
                ),
                clipBehavior: Clip.antiAlias,
                child: SheetCrop(image: sheet.image, region: sheet.cartoon),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// [child] full screen with pinch-to-zoom; a tap or the close button goes back.
Future<void> showZoomable(BuildContext context, Widget child) => showDialog(
  context: context,
  barrierColor: Colors.black.withValues(alpha: 0.92),
  builder: (context) => Stack(
    children: [
      Positioned.fill(
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(maxScale: 5, child: Center(child: child)),
        ),
      ),
      SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: IconButton.filled(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
          ),
        ),
      ),
    ],
  ),
);

/// The whole printed sheet, full screen — built from the letters and the
/// cartoon when only the cartoon is stored.
void showWholeSheet(BuildContext context, Puzzle puzzle) {
  if (!puzzle.cartoonOnly) {
    showZoomable(context, Image(image: sheetProvider(puzzle.image), fit: BoxFit.contain));
    return;
  }
  final layout = PageLayout(
    [for (final w in puzzle.words) w.scrambled],
    [for (final w in puzzle.words) w.circles],
    puzzle.finalGroups,
  );
  showZoomable(
    context,
    FutureBuilder(
      future: File(puzzle.image.path).readAsBytes(),
      builder: (context, snap) =>
          snap.data == null ? const CircularProgressIndicator() : PuzzlePage(layout: layout, cartoon: snap.data!),
    ),
  );
}
