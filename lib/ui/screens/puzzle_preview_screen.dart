import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../game/puzzle_page.dart';
import '../../models/puzzle.dart';
import '../theme.dart';
import '../widgets/sheet_views.dart';

/// Admins only: a published (or unpublished) puzzle as players get it, with
/// every answer beside it. Only for looking: nothing here is played or scored.
class PuzzlePreviewScreen extends StatelessWidget {
  const PuzzlePreviewScreen({super.key, required this.puzzle});

  final Puzzle puzzle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(longDate(puzzle.publishDate))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GestureDetector(
              onTap: () => showWholeSheet(context, puzzle),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _Page(puzzle: puzzle),
              ),
            ),
            const SizedBox(height: 4),
            Text('Tap the page to zoom.', style: TextStyle(color: p.inkSoft)),
            const SizedBox(height: 20),
            Text('Words', style: t.titleMedium),
            for (final w in puzzle.words)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(w.scrambled, style: const TextStyle(fontFamily: 'monospace', letterSpacing: 2)),
                trailing: Text(w.answer, style: t.titleMedium),
              ),
            const SizedBox(height: 12),
            Text('Final answer', style: t.titleMedium),
            const SizedBox(height: 4),
            Text(puzzle.finalAnswer, style: t.titleLarge),
            if (puzzle.finalClue.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Clue', style: t.titleMedium),
              Text(puzzle.finalClue),
            ],
            if (puzzle.finalExplanation.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Why', style: t.titleMedium),
              Text(puzzle.finalExplanation, style: TextStyle(color: p.inkSoft)),
            ],
            const SizedBox(height: 12),
            Text(
              '${puzzle.published ? 'Published' : 'Unpublished'} · ${puzzle.difficulty} · '
              '${puzzle.timeLimitSeconds ~/ 60} min',
              style: TextStyle(color: p.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

/// The page as players see it: built from the letters when only the cartoon
/// is stored, otherwise the stored sheet.
class _Page extends StatelessWidget {
  const _Page({required this.puzzle});

  final Puzzle puzzle;

  @override
  Widget build(BuildContext context) {
    if (!puzzle.cartoonOnly) return Image(image: sheetProvider(puzzle.image), fit: BoxFit.contain);
    final layout = PageLayout(
      [for (final w in puzzle.words) w.scrambled],
      [for (final w in puzzle.words) w.circles],
      puzzle.finalGroups,
    );
    return FutureBuilder(
      future: File(puzzle.image.path).readAsBytes(),
      builder: (context, snap) => snap.data == null
          ? AspectRatio(
              aspectRatio: layout.aspectRatio,
              child: Center(
                child: snap.hasError
                    ? const Text('The cartoon is not on this phone yet.')
                    : const CircularProgressIndicator(),
              ),
            )
          : PuzzlePage(layout: layout, cartoon: snap.data!),
    );
  }
}
