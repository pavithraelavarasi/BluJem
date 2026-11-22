import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../admin/admin_service.dart';
import '../../core/dates.dart';
import '../../data/puzzle_library.dart';
import '../../models/puzzle.dart';
import '../theme.dart';

/// Whether an admin can edit [puzzle] here: a cartoon puzzle (the page is
/// built from its letters), not an old full newspaper sheet.
bool canEditPuzzle(Puzzle puzzle) => puzzle.cartoonOnly || puzzle.sheetKey.startsWith('puzzles/');

/// [puzzle]'s letters as an admin types them: each word with its circled
/// letters in capitals, a blank line, then the answer boxes.
String puzzleTextOf(Puzzle puzzle) {
  final words = [
    for (final w in puzzle.words)
      [
        for (var i = 0; i < w.scrambled.length; i++)
          i < w.circles.length && w.circles[i] ? w.scrambled[i].toUpperCase() : w.scrambled[i].toLowerCase(),
      ].join(),
  ];
  return '${words.join('\n')}\n\n${puzzle.finalPattern}';
}

/// Admins only: changes a puzzle already uploaded — live, scheduled or
/// unpublished — in place. Its words, answers, caption and pictures can all
/// change; its date and slot stay. Players keep their results, the opening
/// time stays, and no second notification goes out. The same save as Edit on
/// the upload page.
class EditPuzzleScreen extends StatefulWidget {
  const EditPuzzleScreen({super.key, required this.puzzle});
  final Puzzle puzzle;

  @override
  State<EditPuzzleScreen> createState() => _EditPuzzleScreenState();
}

class _EditPuzzleScreenState extends State<EditPuzzleScreen> {
  late final _text = TextEditingController(text: puzzleTextOf(widget.puzzle));
  late final _answers = [for (final w in widget.puzzle.words) TextEditingController(text: w.answer)];
  late final _final = TextEditingController(text: _lettersOnly(widget.puzzle.finalAnswer));
  late final _clue = TextEditingController(text: widget.puzzle.finalClue);
  late final _explanation = TextEditingController(text: widget.puzzle.finalExplanation);
  Uint8List? _cartoon;
  Uint8List? _wordless;
  File? _currentWordless;
  bool _saving = false;
  String? _error;

  static String _lettersOnly(String answer) => answer.replaceAll(RegExp('[^A-Za-z]+'), ' ').trim();

  @override
  void initState() {
    super.initState();
    context.read<PuzzleLibrary>().wordlessImage(widget.puzzle).then((f) {
      if (mounted) setState(() => _currentWordless = f);
    });
  }

  @override
  void dispose() {
    for (final c in [_text, _final, _clue, _explanation, ..._answers]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<Uint8List?> _pick() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000);
    return picked?.readAsBytes();
  }

  Future<void> _save() async {
    final answers = [for (final c in _answers) c.text.trim()];
    if (answers.any((a) => a.isEmpty) || _final.text.trim().isEmpty) {
      setState(
        () => _error = 'Fill in every answer and the final answer: without them the puzzle stops being published.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final library = context.read<PuzzleLibrary>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final reply = await context.read<AdminService>().editPuzzle(
        widget.puzzle,
        text: _text.text,
        answers: answers,
        finalAnswer: _final.text.trim(),
        clue: _clue.text.trim(),
        explanation: _explanation.text.trim(),
        cartoon: _cartoon == null ? null : await shrinkForUpload(_cartoon!),
        wordless: _wordless == null ? null : await shrinkForUpload(_wordless!),
      );
      await library.sync();
      messenger.showSnackBar(
        SnackBar(content: Text(reply.published ? 'Saved. Players get the change.' : 'Saved, but not published.')),
      );
      navigator.pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final puzzle = widget.puzzle;
    final current = puzzle.image.isAsset ? null : File(puzzle.image.path);
    return Scaffold(
      appBar: AppBar(title: Text('Edit · ${dayLabel(puzzle.publishDate)} · ${puzzle.slotKind.label}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(12)),
              child: Text(
                'Saved in place: same puzzle and opening time, players keep their results and get no second '
                'notification. Choose a picture only to replace it.',
                style: TextStyle(color: p.ink, height: 1.35),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _PictureChoice(
                    title: 'Cartoon',
                    current: current,
                    picked: _cartoon,
                    onPick: () async {
                      final bytes = await _pick();
                      if (bytes != null && mounted) setState(() => _cartoon = bytes);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PictureChoice(
                    title: 'Wordless cartoon',
                    current: _currentWordless,
                    picked: _wordless,
                    onPick: () async {
                      final bytes = await _pick();
                      if (bytes != null && mounted) setState(() => _wordless = bytes);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Letters', style: t.titleMedium),
            Text(
              'One word per line with the circled letters in capitals, then the answer squares.',
              style: TextStyle(color: p.inkSoft),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _text,
              minLines: 6,
              maxLines: null,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 18),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            Text('Answers', style: t.titleMedium),
            for (var i = 0; i < _answers.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: _answers[i],
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  decoration: InputDecoration(labelText: 'Word ${i + 1}', border: const OutlineInputBorder()),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _final,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Final answer',
                helperText: "Letters in the boxes' order; punctuation comes from the boxes.",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _clue,
              decoration: const InputDecoration(labelText: 'Caption / clue', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _explanation,
              decoration: const InputDecoration(
                labelText: "Why it's funny (shown after solving)",
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: TextStyle(color: p.warning))],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Saving…' : 'Save changes'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A picture as it is now, or the new one picked to replace it.
class _PictureChoice extends StatelessWidget {
  const _PictureChoice({required this.title, required this.current, required this.picked, required this.onPick});
  final String title;
  final File? current;
  final Uint8List? picked;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Widget preview = picked != null
        ? Image.memory(picked!, fit: BoxFit.contain)
        : current != null && current!.existsSync()
        ? Image.file(current!, fit: BoxFit.contain)
        : Center(
            child: Text('None', style: TextStyle(color: p.inkFaint)),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Container(
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: picked != null ? p.success : p.rule, width: picked != null ? 2 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: preview,
        ),
        const SizedBox(height: 4),
        Text(picked != null ? 'New — replaces it' : 'Now', style: TextStyle(color: p.inkSoft, fontSize: 12)),
        OutlinedButton(onPressed: onPick, child: Text(picked != null ? 'Choose again' : 'Replace')),
      ],
    );
  }
}
