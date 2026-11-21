import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../admin/admin_service.dart';
import '../../admin/typed_puzzle.dart';
import '../../game/puzzle_page.dart';
import '../../core/dates.dart';
import '../../core/slots.dart';
import '../theme.dart';
import 'admin_screen.dart';

/// Admins only: a day's puzzle from just the cartoon and the typed letters.
/// Only those are stored; the page is built from them whenever it is shown.
/// It is checked and published like any other.
class TypeLettersScreen extends StatefulWidget {
  const TypeLettersScreen({super.key, required this.date, required this.slot});

  final DateTime date;

  /// Its slot: four words (six for an old Sunday Mega BluJem).
  final Slot slot;

  @override
  State<TypeLettersScreen> createState() => _TypeLettersScreenState();
}

class _TypeLettersScreenState extends State<TypeLettersScreen> {
  final _text = TextEditingController();
  Uint8List? _cartoon;
  String? _error;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickCartoon() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (mounted) setState(() => _cartoon = bytes);
  }

  Future<void> _next() async {
    final TypedPuzzle puzzle;
    try {
      puzzle = TypedPuzzle.parse(_text.text, words: widget.slot.words);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
      return;
    }
    if (puzzle.circled != puzzle.squares) {
      setState(
        () => _error = '${puzzle.circled} letters are circled (capitals) but the answer has ${puzzle.squares} squares.',
      );
      return;
    }
    setState(() => _error = null);
    final page = PageLayout(puzzle.scrambles, puzzle.circles, puzzle.groups);
    final day = DailyPuzzle(
      date: isoDate(widget.date),
      status: 'TYPED',
      scrambles: puzzle.scrambles,
      clue: puzzle.clue,
      groups: puzzle.groups,
      joins: puzzle.joins,
      squares: page.wordBoxes,
      collageAspect: page.aspectRatio,
      assets: const {},
      problems: const [],
    );
    final published = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PublishScreen(day: day, cartoon: _cartoon, slot: widget.slot, pattern: puzzle.pattern),
      ),
    );
    if (published == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('${dayLabel(isoDate(widget.date))} · ${widget.slot.label}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Cartoon', style: t.titleMedium),
            const SizedBox(height: 8),
            if (_cartoon != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(_cartoon!, height: 220, fit: BoxFit.contain),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _pickCartoon,
              icon: const Icon(Icons.image_rounded),
              label: Text(_cartoon == null ? 'Choose the cartoon' : 'Choose another cartoon'),
            ),
            const SizedBox(height: 20),
            Text('Letters', style: t.titleMedium),
            Text(
              'One word per line with the circled letters in capitals, then the answer squares (□ or _). '
              'The cartoon\'s caption can go on its own line — players see it as the clue.',
              style: TextStyle(color: p.inkSoft),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _text,
              minLines: 8,
              maxLines: null,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 18),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'aDRra\ntuYpT\nhcNRcu\ncRaoCD\n\nThe process is —\n□□□-□□□-□□□',
              ),
            ),
            if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: TextStyle(color: p.warning))],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _cartoon == null || _text.text.trim().isEmpty ? null : _next,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Make the puzzle'),
            ),
          ],
        ),
      ),
    );
  }
}
