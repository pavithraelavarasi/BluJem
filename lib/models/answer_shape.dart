/// How the answer row prints an answer: its letters in groups of squares, and
/// the punctuation printed around them.
///
/// The admin types the answer as the paper prints it — `"CREW'S" SHIP` for
/// “□□□□’□” □□□□. A space, an apostrophe or a hyphen right after a letter
/// ends a group; quotes and other punctuation are printed but take no square.
class AnswerShape {
  const AnswerShape(this.groups, this.marks);

  /// Letters per group of squares, left to right.
  final List<int> groups;

  /// What is printed around the squares.
  final List<AnswerMark> marks;

  int get letters => groups.fold(0, (a, b) => a + b);

  static const _breaks = {"'", '’', '‘', '-', '‐', '–'};

  factory AnswerShape.of(String answer) {
    final groups = <int>[];
    final marks = <AnswerMark>[];
    var run = 0;
    var letters = 0;
    final pending = StringBuffer();
    var opening = StringBuffer();
    var spaced = true;

    void endGroup() {
      if (run > 0) groups.add(run);
      run = 0;
    }

    void flushClosing() {
      if (pending.isNotEmpty && letters > 0) {
        marks.add(AnswerMark(letters - 1, _curly(pending.toString(), opens: false), before: false));
      }
      pending.clear();
    }

    for (final c in answer.trim().split('')) {
      if (isLetter(c)) {
        if (opening.isNotEmpty) {
          marks.add(AnswerMark(letters, _curly(opening.toString(), opens: true), before: true));
          opening = StringBuffer();
        }
        run++;
        letters++;
        spaced = false;
      } else if (c.trim().isEmpty) {
        flushClosing();
        endGroup();
        spaced = true;
      } else if (_breaks.contains(c) && !spaced && run > 0) {
        // An apostrophe or hyphen sits between squares and ends the group.
        flushClosing();
        marks.add(AnswerMark(letters - 1, _curly(c, opens: false), before: false));
        endGroup();
        spaced = true;
        opening = StringBuffer();
      } else if (spaced || letters == 0) {
        opening.write(c);
      } else {
        pending.write(c);
      }
    }
    flushClosing();
    endGroup();
    return AnswerShape(groups, marks.where((m) => m.index >= 0 && m.index < letters).toList());
  }

  /// [answer]'s groups when they account for every one of [squares], otherwise
  /// one group, so a mistyped answer never lays out the wrong number of squares.
  static List<int> groupsFor(String answer, int squares) {
    final groups = AnswerShape.of(answer).groups;
    return groups.fold<int>(0, (a, b) => a + b) == squares ? groups : [squares];
  }

  static String _curly(String text, {required bool opens}) =>
      text.replaceAll('"', opens ? '“' : '”').replaceAll("'", opens ? '‘' : '’');
}

/// [text] printed against letter [index]: just before it when [before].
class AnswerMark {
  const AnswerMark(this.index, this.text, {required this.before});

  final int index;
  final String text;
  final bool before;

  @override
  bool operator ==(Object other) =>
      other is AnswerMark && other.index == index && other.text == text && other.before == before;

  @override
  int get hashCode => Object.hash(index, text, before);

  @override
  String toString() => 'Mark($index, $text, ${before ? 'before' : 'after'})';
}

final _letter = RegExp(r'\p{L}', unicode: true);

bool isLetter(String c) => _letter.hasMatch(c);

/// The letters of [text] alone, upper-cased: CREW'S SHIP is CREWSSHIP.
String lettersOf(String text) => text.split('').where(isLetter).join().toUpperCase();
