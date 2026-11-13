import 'package:blujem/models/box_rect.dart';
import 'package:blujem/models/puzzle.dart';

List<BoxRect> boxes(int n, {Set<int> circled = const {}}) => [
  for (var i = 0; i < n; i++) BoxRect(0.1 + i * 0.08, 0.2, 0.07, 0.06, circled: circled.contains(i)),
];

/// A small sheet: RAJA → AJAR, FLOW → WOLF, TYSA → STAY. Their circled
/// letters, in order, are J A · W O L · T A Y, which spell JOLT AWAY.
Puzzle samplePuzzle({String id = 'sample', String publishDate = '2026-10-27', String finalAnswer = 'JOLT AWAY'}) =>
    Puzzle(
      id: id,
      publishDate: publishDate,
      sheetDate: 'Oct 27',
      difficulty: 'Easy',
      timeLimitSeconds: 300,
      image: const SheetImage.asset('assets/bundled/sheet_jul18.png'),
      aspectRatio: 0.85,
      words: [
        PuzzleWord(
          id: 1,
          scrambled: 'RAJA',
          answer: 'AJAR',
          boxes: boxes(4, circled: {1, 2}),
        ),
        PuzzleWord(
          id: 2,
          scrambled: 'FLOW',
          answer: 'WOLF',
          boxes: boxes(4, circled: {0, 1, 2}),
        ),
        PuzzleWord(
          id: 3,
          scrambled: 'TYSA',
          answer: 'STAY',
          boxes: boxes(4, circled: {1, 2, 3}),
        ),
      ],
      finalAnswer: finalAnswer,
      finalBoxes: boxes(8),
      finalClue: 'A clue —',
      finalExplanation: 'Because.',
    );
