import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../admin/admin_service.dart';
import '../../admin/sheet_builder.dart';
import '../../admin/word_index.dart';
import '../../core/dates.dart';
import '../../core/slots.dart';
import '../../game/puzzle_page.dart';
import '../../data/puzzle_library.dart';
import '../../models/answer_shape.dart';
import '../../models/box_rect.dart';
import '../../models/puzzle.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'puzzle_preview_screen.dart';
import 'type_letters_screen.dart';

/// Admins only: upload the day's newspaper puzzle, follow it while the server
/// reads it, then check the answers and publish it to every player.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  /// How often, and how many times, a request is checked: up to five minutes.
  /// A check costs the server a few milliseconds, so it is often enough that
  /// the result shows within seconds of being ready.
  static const _pollEvery = Duration(seconds: 3);
  static const _polls = 100;

  List<DailyPuzzle>? _days;
  bool _loading = false;
  String? _progress;
  String? _message;
  DateTime _date = dateOnly(DateTime.now());
  late Slot _slot = Slot.defaultFor(isoDate(_date));

  AdminService get _service => context.read<AdminService>();

  /// [_date], keeping the slot when that day has it.
  void _setDate(DateTime day) {
    _date = day;
    if (!Slot.forDate(isoDate(day)).contains(_slot)) _slot = Slot.defaultFor(isoDate(day));
  }

  @override
  void initState() {
    super.initState();
    _load();
    unawaited(WordIndex.load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final days = await _service.list();
      if (mounted) setState(() => _days = days);
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not load the prepared puzzles: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today.subtract(const Duration(days: 7)),
      lastDate: today.add(const Duration(days: 60)),
    );
    if (picked != null) setState(() => _setDate(picked));
  }

  Future<void> _upload() async {
    final picked = await ImagePicker().pickMultiImage(limit: 3);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _message = null;
      _progress = 'Preparing the picture…';
    });
    try {
      final images = await Future.wait([for (final f in picked.take(3)) f.readAsBytes().then(shrinkForUpload)]);
      if (!mounted) return;
      setState(() => _progress = 'Sending the puzzle…');
      final id = await _service.start(images, date: isoDate(_date));
      if (!mounted) return;
      final reading = Stopwatch()..start();
      setState(() => _progress = 'Reading and drawing the puzzle — usually under two minutes…');
      var status = 'PENDING';
      for (var i = 0; i < _polls && status == 'PENDING' && mounted; i++) {
        await Future<void>.delayed(_pollEvery);
        if (mounted) {
          setState(
            () => _progress =
                'Reading and drawing the puzzle — ${reading.elapsed.inSeconds} s so far, '
                'usually under two minutes…',
          );
        }
        try {
          status = await _service.status(id);
        } catch (_) {
          // A missed check is retried on the next one.
        }
      }
      if (!mounted) return;
      setState(() {
        _progress = null;
        _message = switch (status) {
          'RENDERED' => 'The puzzle is ready. Open it below to check the answers and publish.',
          'NEEDS_REVIEW' => 'The puzzle is ready, but something needs checking — open it below.',
          'STALE_SOURCE' => "That isn't the puzzle for ${monthDay(_date)}, so nothing was drawn.",
          'PENDING' => 'Still working — pull down to refresh in a minute.',
          _ => 'The puzzle could not be read. Try a clearer image.',
        };
      });
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          _progress = null;
          _message = '$e';
        });
      }
    }
  }

  Future<void> _typeLetters() async {
    final date = _date;
    final slot = _slot;
    final published = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TypeLettersScreen(date: date, slot: slot),
      ),
    );
    if (published == true && mounted) {
      setState(() => _message = 'Published for ${monthDay(date)}, ${slot.heading.toLowerCase()}.');
    }
  }

  /// Takes [puzzle] down; it moves to Unpublished, ready to go back.
  Future<void> _takeDown(Puzzle puzzle) async {
    final library = context.read<PuzzleLibrary>();
    final day = monthDay(DateTime.parse(puzzle.publishDate));
    if (!await confirm(
      context,
      'Unpublish $day?',
      'Players will no longer get this puzzle (answer ${puzzle.finalAnswer}). You can republish it after.',
      'Unpublish',
    )) {
      return;
    }
    await _busy('Unpublishing $day…', () async {
      await _service.unpublish(puzzle);
      library.rememberTakenDown(puzzle);
      await library.sync();
      return '$day is unpublished.';
    });
  }

  /// Puts [puzzle] back for players, taking down whatever replaced it.
  Future<void> _republish(Puzzle puzzle) async {
    final library = context.read<PuzzleLibrary>();
    final date = DateTime.parse(puzzle.publishDate);
    final day = monthDay(date);
    final live = library.published.where((p) => p.publishDate == puzzle.publishDate).firstOrNull;
    if (!await confirm(
      context,
      'Republish $day?',
      live == null
          ? 'Players will get this puzzle again (answer ${puzzle.finalAnswer}).'
          : 'Players will get this puzzle (answer ${puzzle.finalAnswer}) instead of the one published now '
                '(answer ${live.finalAnswer}).',
      'Republish',
    )) {
      return;
    }
    await _busy('Republishing $day…', () async {
      await _service.republish(puzzle);
      library.forgetTakenDown(puzzle.id);
      if (live != null) {
        await _service.unpublish(live);
        library.rememberTakenDown(live);
      }
      await library.sync();
      return '$day is published again.';
    });
  }

  /// Runs [work] with [progress] showing; its reply, or the error, is the message after.
  Future<void> _busy(String progress, Future<String> Function() work) async {
    setState(() {
      _message = null;
      _progress = progress;
    });
    try {
      final done = await work();
      if (mounted) setState(() => _message = done);
    } catch (e) {
      if (mounted) setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  Future<void> _open(DailyPuzzle day) async {
    final published = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PublishScreen(day: day, slot: _slot),
      ),
    );
    if (published == true && mounted) {
      setState(() => _message = 'Published for ${monthDay(DateTime.parse(day.date))}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final library = context.watch<PuzzleLibrary>();
    final busy = _progress != null;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
            children: [
              const PageTitle('Upload'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Upload a puzzle', style: t.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Type the letters and choose the cartoon: only those are stored, and the app builds the page. '
                          'Or choose the newspaper puzzle image — one picture of the whole puzzle, or up to three '
                          'pieces — and the server reads it.',
                          style: TextStyle(color: p.inkSoft),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: busy ? null : _pickDate,
                          icon: const Icon(Icons.event_rounded),
                          label: Text('For ${longDate(isoDate(_date))}'),
                        ),
                        const SizedBox(height: 8),
                        SlotPicker(date: _date, slot: _slot, onChanged: busy ? null : (s) => setState(() => _slot = s)),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: busy ? null : _typeLetters,
                          icon: const Icon(Icons.keyboard_rounded),
                          label: const Text('Type the letters'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: busy ? null : _upload,
                          icon: const Icon(Icons.upload_rounded),
                          label: const Text('Choose puzzle image'),
                        ),
                        if (busy) ...[
                          const SizedBox(height: 16),
                          const LinearProgressIndicator(),
                          const SizedBox(height: 8),
                          Text(_progress!, style: TextStyle(color: p.inkSoft)),
                        ],
                        if (_message != null) ...[const SizedBox(height: 12), Text(_message!)],
                      ],
                    ),
                  ),
                ),
              ),
              if (library.published.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
                  child: Text('Published', style: t.titleMedium),
                ),
                for (final puzzle in library.published.take(14))
                  _PuzzleTile(puzzle: puzzle, action: 'Unpublish', onAction: busy ? null : () => _takeDown(puzzle)),
              ],
              if (library.takenDown.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
                  child: Text('Unpublished', style: t.titleMedium),
                ),
                for (final puzzle in library.takenDown)
                  _PuzzleTile(puzzle: puzzle, action: 'Republish', onAction: busy ? null : () => _republish(puzzle)),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Row(
                  children: [
                    Expanded(child: Text('Prepared puzzles', style: t.titleMedium)),
                    if (_loading)
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh'),
                  ],
                ),
              ),
              if (_days != null && _days!.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Nothing prepared yet.', style: TextStyle(color: p.inkSoft)),
                ),
              for (final day in _days ?? const <DailyPuzzle>[])
                _DayTile(
                  day: day,
                  published: library.forDay(DateTime.parse(day.date)) != null,
                  onTap: day.canDraft ? () => _open(day) : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A puzzle players get, or got: its day and answer, with [action] beside it.
/// A tap opens it to look at, answers and all.
class _PuzzleTile extends StatelessWidget {
  const _PuzzleTile({required this.puzzle, required this.action, this.onAction});

  final Puzzle puzzle;
  final String action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: () =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PuzzlePreviewScreen(puzzle: puzzle))),
    title: Text(longDate(puzzle.publishDate)),
    subtitle: Text(
      '${puzzle.slotKind.heading}'
      '${puzzle.releasedAt.isAfter(DateTime.now().toUtc()) ? ' · scheduled' : ''}\n${puzzle.finalAnswer}',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    isThreeLine: true,
    trailing: OutlinedButton(onPressed: onAction, child: Text(action)),
  );
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.day, required this.published, this.onTap});

  final DailyPuzzle day;
  final bool published;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (label, color) = published
        ? ('Published', p.success)
        : switch (day.status) {
            'RENDERED' => ('Ready', p.accent),
            'NEEDS_REVIEW' => ('Check', p.warning),
            'PENDING' => ('Working', p.inkSoft),
            'STALE_SOURCE' => ('Wrong day', p.warning),
            _ => ('Failed', p.warning),
          };
    return ListTile(
      onTap: onTap,
      title: Text(longDate(day.date)),
      subtitle: Text(
        day.failure?.isNotEmpty == true
            ? day.failure!
            : day.scrambles.isEmpty
            ? day.status
            : day.scrambles.join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
            child: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          if (onTap != null) const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

/// One prepared day: the drawn sheet, its words to answer, the cartoon answer
/// to settle, and Publish.
class PublishScreen extends StatefulWidget {
  const PublishScreen({super.key, required this.day, this.cartoon, this.slot, this.pattern = ''});

  final DailyPuzzle day;

  /// The slot to publish in; the date's first when not given.
  final Slot? slot;

  /// The answer boxes as typed, with their line breaks, when typed.
  final String pattern;

  /// For a typed puzzle, its cartoon picture: the page is built from the
  /// letters, and only the cartoon is stored. Otherwise the server's collage
  /// is downloaded.
  final Uint8List? cartoon;

  @override
  State<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends State<PublishScreen> {
  late final _answers = [for (final _ in widget.day.scrambles) TextEditingController()];
  late final _clue = TextEditingController(text: widget.day.clue);
  final _final = TextEditingController();
  final _explanation = TextEditingController();
  late List<List<String>> _options = [for (final _ in widget.day.scrambles) const <String>[]];
  List<String> _finalOptions = const [];

  /// Whether [_finalOptions] came from circles that don't fill the printed squares.
  bool _finalGuessed = false;
  late DateTime _date = _startDate();
  late Slot _slot = widget.slot != null && Slot.forDate(isoDate(_date)).contains(widget.slot)
      ? widget.slot!
      : Slot.defaultFor(isoDate(_date));

  /// Which squares are circled. The server's reading, which can miss one, so
  /// the admin can tap a square to fix it.
  String? _circlesNote;
  late final List<List<bool>> _circles = [
    for (final w in widget.day.squares) [for (final b in w) b.circled],
  ];
  Uint8List? _collage;
  String? _error;
  bool _solving = false;
  bool _publishing = false;

  AdminService get _service => context.read<AdminService>();
  DailyPuzzle get _day => widget.day;

  /// The day it was prepared for; a past one is offered for today, unless it
  /// was published then — opening it is to change that day's puzzle, never to
  /// replace today's by surprise.
  DateTime _startDate() {
    final today = dateOnly(DateTime.now());
    final day = DateTime.tryParse(_day.date) ?? today;
    if (!day.isBefore(today)) return day;
    final library = context.read<PuzzleLibrary>();
    final published = library.forDay(day);
    return published != null && !published.image.isAsset ? day : today;
  }

  @override
  void initState() {
    super.initState();
    for (final c in [..._answers, _final, _clue]) {
      c.addListener(() => setState(() {}));
    }
    _final.addListener(_fitCircles);
    for (final c in _answers) {
      c.addListener(_fitCircles);
    }
    _prepare();
  }

  @override
  void dispose() {
    for (final c in [..._answers, _clue, _final, _explanation]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Downloads the collage and drafts every answer the dictionary is sure of.
  Future<void> _prepare() async {
    try {
      if (widget.cartoon == null) {
        final collage = await _service.asset(_day.assets[DailyPuzzle.collage]!);
        if (mounted) setState(() => _collage = collage);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
    final index = await WordIndex.load();
    if (!mounted) return;
    setState(() => _options = [for (final s in _day.scrambles) index.unscramble(s)]);
    await Future.wait([
      for (var i = 0; i < _day.scrambles.length; i++)
        () async {
          final scramble = _day.scrambles[i];
          final answer =
              index.best(scramble) ??
              (_options[i].length > 1 ? await _service.pickWord(scramble, _options[i], _clue.text) : null) ??
              _options[i].firstOrNull;
          if (answer != null && mounted && _answers[i].text.isEmpty) _answers[i].text = answer;
        }(),
    ]);
    if (mounted && _wordsDone) await _suggestFinal();
  }

  String _letters(String s) => s.toUpperCase().replaceAll(RegExp('[^A-Z]'), '');

  /// Why word [i]'s answer cannot be used, or null when it can.
  String? _wordProblem(int i) {
    final answer = _letters(_answers[i].text);
    if (answer.isEmpty) return null;
    if (answer.length != _day.squares[i].length) return 'Needs ${_day.squares[i].length} letters.';
    if (!sameLetters(answer, _day.scrambles[i])) return "Doesn't use the letters ${_day.scrambles[i]}.";
    return null;
  }

  bool get _wordsDone =>
      [for (var i = 0; i < _answers.length; i++) _letters(_answers[i].text).isNotEmpty && _wordProblem(i) == null]
          .every((ok) => ok);

  /// The circled letters, in word order, as far as the answers go.
  String get _circled {
    final out = StringBuffer();
    for (var i = 0; i < _answers.length; i++) {
      final answer = _letters(_answers[i].text);
      final circles = _circles[i];
      for (var j = 0; j < circles.length && j < answer.length; j++) {
        if (circles[j]) out.write(answer[j]);
      }
    }
    return out.toString();
  }

  /// Corrects misread circles from the typed answer: squares holding the
  /// missing letters are circled, and squares holding extra ones uncircled.
  /// When a letter could go in more than one square, the word with the fewest
  /// circles gets it — words share the circles out — and the admin is asked
  /// to check them against the paper.
  void _fitCircles() {
    final answer = _letters(_final.text);
    if (!_wordsDone || answer.isEmpty || sameLetters(answer, _circled)) return;
    if (_printedCount > 0 && answer.length != _printedCount) return;

    Map<String, int> count(String s) {
      final m = <String, int>{};
      for (final c in s.split('')) {
        m[c] = (m[c] ?? 0) + 1;
      }
      return m;
    }

    final want = count(answer), have = count(_circled);
    final circles = [
      for (final w in _circles) [...w],
    ];
    int circledIn(int i) => circles[i].where((c) => c).length;
    var guessed = false;

    for (final (from, to, add) in [(want, have, true), (have, want, false)]) {
      for (final e in from.entries) {
        var needed = e.value - (to[e.key] ?? 0);
        while (needed > 0) {
          final squares = [
            for (var i = 0; i < _answers.length; i++)
              for (var j = 0; j < circles[i].length; j++)
                if (circles[i][j] != add && _letters(_answers[i].text)[j] == e.key) (i, j),
          ];
          if (squares.isEmpty) return;
          if (squares.length > needed) guessed = true;
          squares.sort((a, b) => add ? circledIn(a.$1) - circledIn(b.$1) : circledIn(b.$1) - circledIn(a.$1));
          final (i, j) = squares.first;
          circles[i][j] = add;
          needed--;
        }
      }
    }
    setState(() {
      for (var i = 0; i < circles.length; i++) {
        _circles[i].setAll(0, circles[i]);
      }
      _circlesNote = guessed
          ? 'Circles changed to fit the answer — check them against the paper.'
          : 'Circles fixed to fit the answer.';
    });
  }

  int get _circleCount => _circles.expand((w) => w).where((c) => c).length;

  /// Answer squares the paper prints, when the server read them.
  int get _printedCount => _day.groups.fold(0, (a, b) => a + b);

  List<List<BoxRect>> get _squares => [
    for (var i = 0; i < _day.squares.length; i++)
      [
        for (var j = 0; j < _day.squares[i].length; j++)
          BoxRect(
            _day.squares[i][j].x,
            _day.squares[i][j].y,
            _day.squares[i][j].w,
            _day.squares[i][j].h,
            circled: _circles[i][j],
          ),
      ],
  ];

  String? get _finalProblem {
    final answer = _letters(_final.text);
    if (answer.isEmpty) return null;
    if (_printedCount > 0 && answer.length != _printedCount) {
      return 'The paper prints $_printedCount answer squares; this has ${answer.length} letters.';
    }
    if (answer.length != _circleCount) {
      return '$_circleCount squares are circled but the answer has ${answer.length} letters. '
          'Tap the squares above to match the circles on the paper.';
    }
    if (_wordsDone && !sameLetters(answer, _circled)) return 'Must use exactly the circled letters $_circled.';
    final groups = AnswerShape.groupsFor(_final.text, answer.length);
    if (_day.groups.isNotEmpty && groups.join(',') != _day.groups.join(',')) {
      return 'The paper prints ${_day.groups.join(' + ')} letters per word; this is ${groups.join(' + ')}.';
    }
    return null;
  }

  /// Fills the cartoon answer: the AI's reading when it has one, else the
  /// commonest phrase the dictionary spells from the circled letters. The
  /// other phrases are offered beside it. When the circles don't fill the
  /// printed squares the phrases are a guess, so they are only offered.
  Future<void> _suggestFinal() async {
    setState(() => _solving = true);
    final service = _service;
    final index = await WordIndex.load();
    if (!mounted) return;
    final phrases = finalPhrases(index, _circledFrom(), _day.groups);
    final guessed = _printedCount > 0 && _circleCount != _printedCount;
    final reply = await service.solveFinal(
      circled: _circled,
      groups: _day.groups,
      clue: _clue.text,
      solvedWords: [for (final a in _answers) _letters(a.text)],
    );
    if (!mounted) return;
    setState(() {
      _solving = false;
      _finalGuessed = guessed;
      _finalOptions = [
        ?reply?.answer,
        for (final p in phrases.map(_printed))
          if (p != reply?.answer) p,
      ];
    });
    if (_finalOptions.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No suggestion — type the answer from the cartoon.')));
      return;
    }
    if (!guessed) _final.text = _finalOptions.first;
    if (reply != null && _explanation.text.isEmpty) _explanation.text = reply.explanation;
  }

  /// [phrase] as the paper prints it: CUT AND DRY as CUT-AND-DRY.
  String _printed(String phrase) {
    final words = phrase.split(' ');
    if (words.length != _day.joins.length + 1) return phrase;
    final out = StringBuffer(words.first);
    for (var i = 1; i < words.length; i++) {
      out
        ..write(_day.joins[i - 1])
        ..write(words[i]);
    }
    return out.toString();
  }

  /// Every square's letter, with whether it is circled — what [finalPhrases] reads.
  List<({String letter, bool circled})> _circledFrom() => [
    for (var i = 0; i < _answers.length; i++)
      for (var j = 0; j < _circles[i].length && j < _letters(_answers[i].text).length; j++)
        (letter: _letters(_answers[i].text)[j], circled: _circles[i][j]),
  ];

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _date.isBefore(today) ? _date : today,
      lastDate: today.add(const Duration(days: 60)),
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
      if (!Slot.forDate(isoDate(picked)).contains(_slot)) _slot = Slot.defaultFor(isoDate(picked));
    });
  }

  bool get _ready => _waitingFor == null && !_publishing;

  /// What still has to be done before publishing, or null when nothing.
  String? get _waitingFor {
    if (_collage == null && widget.cartoon == null) return 'Waiting for the puzzle picture…';
    if (!_wordsDone) return 'Answer every word to publish.';
    if (_letters(_final.text).isEmpty) return 'Type the final answer to publish.';
    if (_finalProblem != null) return 'Fix the final answer to publish.';
    return null;
  }

  /// The puzzle published for [_date]'s [_slot], when the server has one.
  Puzzle? _liveOn(PuzzleLibrary library) => library.forSlot(_date, _slot);

  Future<bool> _confirm(String title, String message, String action) => confirm(context, title, message, action);

  /// Takes down what is published on [_date], so it can be published again.
  Future<void> _unpublish(Puzzle live) async {
    final library = context.read<PuzzleLibrary>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _confirm(
      'Unpublish ${monthDay(_date)}?',
      'Players will no longer get this puzzle (answer ${live.finalAnswer}). You can publish it again after.',
      'Unpublish',
    );
    if (!ok || !mounted) return;
    setState(() {
      _publishing = true;
      _error = null;
    });
    try {
      await _service.unpublish(live);
      library.rememberTakenDown(live);
      await library.sync();
      messenger.showSnackBar(
        SnackBar(content: Text('${monthDay(_date)} is unpublished. Publish it again when ready.')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _publish() async {
    final library = context.read<PuzzleLibrary>();
    if (library.forDay(_date) case final p? when p.image.isAsset) {
      setState(() => _error = '${monthDay(_date)} already has a puzzle. Pick another date.');
      return;
    }
    // Replacing goes out as a new puzzle, so phones fetch its new sheet; the
    // old one is taken down once this one is up.
    final live = _liveOn(library);
    if (live != null &&
        !await _confirm(
          'Replace ${monthDay(_date)}?',
          'Players will get this puzzle instead of the one published now (answer ${live.finalAnswer}).',
          'Replace',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _publishing = true;
      _error = null;
    });
    try {
      final finalAnswer = _final.text.trim().toUpperCase();
      final groups = AnswerShape.groupsFor(finalAnswer, _letters(finalAnswer).length);
      final cartoon = widget.cartoon;
      final ({Uint8List png, double aspectRatio, List<List<BoxRect>> words, List<BoxRect> finalBoxes}) built;
      if (cartoon != null) {
        final page = PageLayout(_day.scrambles, _circles, groups);
        built = (
          png: await shrinkForUpload(cartoon),
          aspectRatio: page.aspectRatio,
          words: page.wordBoxes,
          finalBoxes: page.answerBoxes,
        );
      } else {
        built = await buildSheet(_collage!, _squares, groups);
      }
      await _service.publish(
        PublishSheet(
          publishDate: isoDate(_date),
          slot: _slot.name,
          finalPattern: widget.pattern,
          image: built.png,
          aspectRatio: built.aspectRatio,
          words: [
            for (var i = 0; i < _answers.length; i++)
              (scrambled: _day.scrambles[i], answer: _letters(_answers[i].text), boxes: built.words[i]),
          ],
          finalAnswer: finalAnswer,
          finalBoxes: built.finalBoxes,
          finalGroups: groups,
          finalClue: _clue.text.trim(),
          finalExplanation: _explanation.text.trim(),
          cartoonOnly: cartoon != null,
        ),
      );
      if (live != null) await _service.unpublish(live);
      await library.sync();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final finalProblem = _finalProblem;
    final live = _liveOn(context.watch<PuzzleLibrary>());

    return Scaffold(
      appBar: AppBar(title: Text(dayLabel(_day.date))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_day.problems.isNotEmpty)
              Card(
                color: p.warning.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Check before publishing', style: t.titleSmall),
                      for (final m in _day.problems) Text('• $m'),
                    ],
                  ),
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: widget.cartoon != null
                  ? PuzzlePage(layout: PageLayout(_day.scrambles, _circles, _day.groups), cartoon: widget.cartoon!)
                  : AspectRatio(
                      aspectRatio: _day.collageAspect,
                      child: _collage == null
                          ? ColoredBox(
                              color: p.sunken,
                              child: const Center(child: CircularProgressIndicator()),
                            )
                          : Image.memory(_collage!, fit: BoxFit.contain),
                    ),
            ),
            const SizedBox(height: 20),
            Text('Words', style: t.titleMedium),
            Text('Tap a square to circle or uncircle it, as on the paper.', style: TextStyle(color: p.inkSoft)),
            if (_circlesNote != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_circlesNote!, style: TextStyle(color: p.accent)),
              ),
            if (_printedCount > 0 && _printedCount != _circleCount)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'The paper prints $_printedCount answer squares but $_circleCount squares are circled — '
                  'one of the circles was misread.',
                  style: TextStyle(color: p.warning),
                ),
              ),
            for (var i = 0; i < _answers.length; i++) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _answers[i],
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: '${_day.scrambles[i]}  →  answer',
                  errorText: _wordProblem(i),
                  errorMaxLines: 2,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),
              _CircleRow(
                letters: _letters(_answers[i].text),
                circles: _circles[i],
                onToggle: (j) {
                  setState(() {
                    _circles[i][j] = !_circles[i][j];
                    _circlesNote = null;
                  });
                  // Circles now matching the paper make a sure suggestion; an
                  // answer the admin typed is left alone.
                  final typed = _final.text.isNotEmpty && !_finalOptions.contains(_final.text);
                  if (_wordsDone && _circleCount == _printedCount && !typed && !_solving) _suggestFinal();
                },
              ),
              if (_options[i].length > 1)
                Wrap(
                  spacing: 6,
                  children: [
                    for (final o in _options[i].take(6))
                      ChoiceChip(
                        label: Text(o),
                        selected: _letters(_answers[i].text) == o,
                        onSelected: (_) => _answers[i].text = o,
                      ),
                  ],
                ),
            ],
            const SizedBox(height: 20),
            Text('Cartoon', style: t.titleMedium),
            const SizedBox(height: 10),
            TextField(
              controller: _clue,
              maxLines: null,
              decoration: InputDecoration(
                labelText: 'Clue (optional)',
                hintText: "The cartoon's caption, e.g. The process is —",
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _wordsDone ? 'Circled letters: $_circled' : 'Answer every word to see the circled letters.',
              style: TextStyle(color: p.inkSoft),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _final,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              decoration: InputDecoration(
                labelText:
                    'Final answer, as printed'
                    '${_day.groups.isEmpty ? '' : ' ($_printedCount letters: ${_day.groups.join(' + ')})'}',
                errorText: finalProblem,
                errorMaxLines: 3,
                border: const OutlineInputBorder(),
                suffixIcon: _solving
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(
                        tooltip: 'Suggest',
                        onPressed: _wordsDone ? _suggestFinal : null,
                        icon: const Icon(Icons.auto_awesome_rounded),
                      ),
              ),
            ),
            if (_finalGuessed && _finalOptions.isNotEmpty && _letters(_final.text).isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 2),
                child: Text(
                  "The circles don't match the paper, so these are guesses — pick the answer, "
                  'or fix the circles above for a sure one.',
                  style: TextStyle(color: p.warning),
                ),
              ),
            if (_finalOptions.length > 1 || _finalGuessed)
              Wrap(
                spacing: 6,
                children: [
                  for (final o in _finalOptions)
                    ChoiceChip(
                      label: Text(o),
                      selected: _letters(_final.text) == _letters(o),
                      onSelected: (_) => _final.text = o,
                    ),
                ],
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _explanation,
              maxLines: null,
              decoration: const InputDecoration(labelText: 'Explanation (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _publishing ? null : _pickDate,
              icon: const Icon(Icons.event_rounded),
              label: Text('Publish for ${longDate(isoDate(_date))}'),
            ),
            const SizedBox(height: 8),
            SlotPicker(date: _date, slot: _slot, onChanged: _publishing ? null : (s) => setState(() => _slot = s)),
            if (live != null) ...[
              const SizedBox(height: 8),
              Card(
                color: p.accent.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${monthDay(_date)} ${_slot.label.toLowerCase()} is published now, answer ${live.finalAnswer}. '
                          'Publishing replaces it.',
                        ),
                      ),
                      TextButton(
                        onPressed: _publishing ? null : () => _unpublish(live),
                        child: const Text('Unpublish'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _ready ? _publish : null,
              icon: _publishing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.publish_rounded),
              label: Text(
                _publishing
                    ? 'Publishing…'
                    : live != null
                    ? 'Replace published puzzle'
                    : 'Publish',
              ),
            ),
            if (!_publishing && _waitingFor != null) ...[
              const SizedBox(height: 8),
              Text(
                _waitingFor!,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.inkSoft),
              ),
            ],
            if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: TextStyle(color: p.warning))],
          ],
        ),
      ),
    );
  }
}

/// A word's squares, circled as they will be played; tap one to change it.
class _CircleRow extends StatelessWidget {
  const _CircleRow({required this.letters, required this.circles, required this.onToggle});

  final String letters;
  final List<bool> circles;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Wrap(
      spacing: 6,
      children: [
        for (var j = 0; j < circles.length; j++)
          Semantics(
            button: true,
            label: 'Square ${j + 1}, ${circles[j] ? 'circled' : 'not circled'}',
            child: InkWell(
              onTap: () => onToggle(j),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.card,
                  border: Border.all(color: p.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: circles[j]
                      ? BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: p.ink, width: 1.5),
                        )
                      : null,
                  child: Text(
                    j < letters.length ? letters[j] : '',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Cartoon answers the dictionary spells from the circled squares, commonest
/// first, as many words as the paper prints [groups].
///
/// The server sometimes misreads a circle or two, so when the circles don't
/// fill the printed squares, every fix of up to two circles is tried as well,
/// and more phrases are offered since the letters are a guess; the admin's
/// circles are then corrected to fit whichever phrase is used.
List<String> finalPhrases(WordIndex index, List<({String letter, bool circled})> squares, List<int> groups) {
  final circled = [
    for (final s in squares)
      if (s.circled) s.letter,
  ];
  final plain = [
    for (final s in squares)
      if (!s.circled) s.letter,
  ];
  final printed = groups.fold(0, (a, b) => a + b);
  final off = printed == 0 ? 0 : circled.length - printed;
  if (off.abs() > 2) return const [];

  /// Every way to take [n] of [letters].
  Iterable<List<String>> take(List<String> letters, int n, [int from = 0]) sync* {
    if (n == 0) {
      yield const [];
      return;
    }
    for (var i = from; i <= letters.length - n; i++) {
      for (final rest in take(letters, n - 1, i + 1)) {
        yield [letters[i], ...rest];
      }
    }
  }

  // Too many circles: one search that may leave the extra letters over.
  if (off >= 0) {
    return [for (final p in index.phrases(circled.join(), groups, spare: off, limit: off == 0 ? 8 : 12)) p.phrase];
  }
  // Too few: each way of taking plain squares in, each set of letters once.
  final found = <String, int>{};
  final pools = {
    for (final extra in take(plain, -off)) ([...circled, ...extra]..sort()).join(),
  };
  for (final pool in pools) {
    for (final p in index.phrases(pool, groups)) {
      if (p.score < (found[p.phrase] ?? 1 << 30)) found[p.phrase] = p.score;
    }
  }
  final ranked = found.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
  return [for (final e in ranked.take(12)) e.key];
}

/// Asks before doing [action]; true when the admin agreed.
Future<bool> confirm(BuildContext context, String title, String message, String action) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
        ],
      ),
    ) ??
    false;

/// The slots of [date] to choose from: morning, afternoon and night, or Sunday's one.
class SlotPicker extends StatelessWidget {
  const SlotPicker({super.key, required this.date, required this.slot, required this.onChanged});

  final DateTime date;
  final Slot slot;
  final ValueChanged<Slot>? onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      for (final s in Slot.forDate(isoDate(date)))
        ChoiceChip(
          label: Text('${s.heading} · ${s.words} words'),
          selected: s == slot,
          onSelected: onChanged == null ? null : (_) => onChanged!(s),
        ),
    ],
  );
}
