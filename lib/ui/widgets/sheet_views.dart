import 'dart:io';
import 'dart:math';
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

/// Mystery tiles: the cartoon sits under a grid of gold BluJem tiles, a few
/// open. The tiles open in an order fixed per puzzle, so the same corners
/// show on the Start screen and stay open as more flip during play.
class MysteryTiles {
  static const columns = 3;
  static const rows = 4;
  static const count = columns * rows;

  /// Open on the Start screen, before any word is solved.
  static const atStart = 3;

  /// Tiles open with [solved] of [total] words done; all of them once every
  /// word is in.
  static int openFor(int solved, int total) =>
      total == 0 ? count : atStart + ((count - atStart) * solved / total).floor();

  /// Which tile opens first, second, and so on, for [puzzle]. The first
  /// [atStart] come from the middle rows: speech bubbles sit at the top and
  /// any caption at the bottom, and either could give the pun away.
  static List<int> order(Puzzle puzzle) {
    final seed = puzzle.id.codeUnits.fold<int>(17, (h, c) => (h * 31 + c) & 0x7fffffff);
    final random = Random(seed);
    bool middle(int i) => i >= columns && i < count - columns;
    final inside = [
      for (var i = 0; i < count; i++)
        if (middle(i)) i,
    ]..shuffle(random);
    final first = inside.take(atStart).toList();
    final rest = [
      for (var i = 0; i < count; i++)
        if (!first.contains(i)) i,
    ]..shuffle(random);
    return [...first, ...rest];
  }
}

/// The cartoon, as large as fits; a tap opens it full screen to zoom.
/// With [open] set, only that many mystery tiles show it; null shows it all.
class CartoonView extends StatelessWidget {
  const CartoonView({super.key, required this.puzzle, this.open, this.zoomable = true});
  final Puzzle puzzle;
  final int? open;
  final bool zoomable;

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
        final open = this.open;
        Widget art = SheetCrop(image: sheet.image, region: sheet.cartoon);
        if (open != null && open < MysteryTiles.count) {
          art = Stack(
            children: [
              art,
              Positioned.fill(
                child: _TileCover(order: MysteryTiles.order(puzzle), open: open),
              ),
            ],
          );
        }
        final framed = Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.rule),
            color: Colors.white,
          ),
          clipBehavior: Clip.antiAlias,
          child: art,
        );
        return Center(
          child: !zoomable
              ? framed
              : Semantics(
                  button: true,
                  label: 'Cartoon. Tap to open full screen',
                  child: GestureDetector(onTap: () => showZoomable(context, art), child: framed),
                ),
        );
      },
    );
  }
}

/// The gold tiles over the cartoon; each opens with a flip when [open] passes it.
class _TileCover extends StatelessWidget {
  const _TileCover({required this.order, required this.open});
  final List<int> order;
  final int open;

  @override
  Widget build(BuildContext context) {
    final opened = order.take(open).toSet();
    return Column(
      children: [
        for (var r = 0; r < MysteryTiles.rows; r++)
          Expanded(
            child: Row(
              children: [
                for (var c = 0; c < MysteryTiles.columns; c++)
                  Expanded(
                    child: _MysteryTile(
                      index: r * MysteryTiles.columns + c,
                      open: opened.contains(r * MysteryTiles.columns + c),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MysteryTile extends StatelessWidget {
  const _MysteryTile({required this.index, required this.open});
  final int index;
  final bool open;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: open ? 0 : 1),
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeInOut,
    builder: (context, shown, _) {
      if (shown <= 0.01) return const SizedBox.expand();
      // Turns edge-on as it opens, like a card flipping away.
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scaleByDouble(1, shown, 1, 1),
        child: Container(
          margin: const EdgeInsets.all(1.5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFE8C547),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFB8952A), width: 1.5),
          ),
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                'BLUJEM'[index % 6],
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF6B4E0E)),
              ),
            ),
          ),
        ),
      );
    },
  );
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
