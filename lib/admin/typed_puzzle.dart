/// A puzzle as the admin types it: one scrambled word per line with a capital
/// for every circled letter, a blank line, then the answer boxes — punctuation
/// kept as printed, a new line where the answer wraps — and the caption on
/// any other line:
///
///     aDRra
///     tuYpT
///     hcNRcu
///     cRaoCD
///
///     □□□-□□□-
///     □□□
///
/// The server reads it the same way (jumble_data/lib/puzzle-text.js); both
/// are tested against test/fixtures/puzzle_text_cases.json.
class TypedPuzzle {
  const TypedPuzzle({
    required this.scrambles,
    required this.circles,
    required this.groups,
    required this.clue,
    this.joins = const [],
    this.pattern = '',
    this.lines = const [],
  });

  /// The scrambled words, in capitals.
  final List<String> scrambles;

  /// For every word, which of its squares are circled.
  final List<List<bool>> circles;

  /// Letters per word of the final answer.
  final List<int> groups;

  /// What is printed between those words: a space, or a hyphen.
  final List<String> joins;

  /// The cartoon's caption, when one was typed.
  final String clue;

  /// The answer boxes as typed, every box a □, lines kept.
  final String pattern;

  /// Which groups share each line of [pattern].
  final List<List<int>> lines;

  /// Squares as pasted (□), or typed on a phone keyboard as _ or #.
  static final _boxes = RegExp('[□☐■◻⬜▢_#]');
  static final _word = RegExp(r'^[A-Za-z]+$');
  static const maxLetters = 8;

  /// Reads [text], or throws a [FormatException] saying what to fix. With
  /// [words] (4, or 6 on Sunday), exactly that many words are required.
  factory TypedPuzzle.parse(String text, {int? words}) {
    final scrambles = <String>[];
    final circles = <List<bool>>[];
    final shape = <String>[];
    final clue = <String>[];
    for (final raw in text.replaceAll('\r', '').split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (_boxes.hasMatch(line)) {
        shape.add(line.replaceAll(_boxes, '□'));
      } else if (RegExp(r'\s').hasMatch(line)) {
        clue.add(line);
      } else {
        if (shape.isNotEmpty) throw FormatException('"$line" comes after the answer boxes — type the words first.');
        if (!_word.hasMatch(line)) throw FormatException('"$line": a scrambled word can have only letters.');
        if (line.length > maxLetters) {
          throw FormatException('"$line" is too long: a word has at most $maxLetters letters.');
        }
        scrambles.add(line.toUpperCase());
        circles.add([for (final c in line.split('')) c != c.toLowerCase()]);
      }
    }
    if (words != null && scrambles.length != words) {
      throw FormatException(
        'Found ${scrambles.length} words, but this puzzle needs $words words${words == 6 ? ' (Sunday)' : ''}.',
      );
    }
    if (scrambles.length < 2) throw const FormatException('Type the scrambled words, one per line.');
    if (scrambles.length > 6) throw const FormatException('A puzzle has at most six words.');
    final circled = circles.expand((c) => c).where((c) => c).length;
    if (circled == 0) {
      throw const FormatException('No circled letters: type the circled letters as capitals, like aDRra.');
    }
    if (shape.isEmpty) {
      throw const FormatException('Type the answer boxes (□□□-□□□) after a blank line under the words.');
    }

    final pattern = shape.join('\n');
    final runs = RegExp('□+');
    final groups = <int>[];
    final lines = <List<int>>[];
    for (final line in shape) {
      final onLine = <int>[];
      for (final m in runs.allMatches(line)) {
        onLine.add(groups.length);
        groups.add(m.group(0)!.length);
      }
      if (onLine.isNotEmpty) lines.add(onLine);
    }
    final boxes = groups.fold(0, (a, b) => a + b);
    if (boxes != circled) {
      throw FormatException('$circled circled letters but $boxes answer boxes: they must be the same.');
    }
    // What is printed between groups: a hyphen or apostrophe, else a space.
    final between = pattern.split(runs);
    final joins = [
      for (final m in between.sublist(1, between.length - 1))
        m.trim().replaceAll(RegExp('["“”]'), '').isEmpty ? ' ' : m.trim().replaceAll(RegExp('["“”]'), ''),
    ];
    return TypedPuzzle(
      scrambles: scrambles,
      circles: circles,
      groups: groups,
      clue: clue.join(' '),
      joins: joins.length == groups.length - 1 ? joins : const [],
      pattern: pattern,
      lines: lines,
    );
  }

  int get circled => circles.expand((c) => c).where((c) => c).length;
  int get squares => groups.fold(0, (a, b) => a + b);
}
