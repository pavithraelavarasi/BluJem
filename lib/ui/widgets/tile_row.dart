import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/board.dart';
import '../../models/answer_shape.dart';
import '../theme.dart';

/// Where each square of a row sits, in groups, wrapped onto more lines when
/// the squares would otherwise be too small to tap.
class TileLayout {
  TileLayout._(this.positions, this.size, this.width, this.height);

  final List<Offset> positions;
  final double size;
  final double width;
  final double height;

  static const double minSize = 34;

  /// [groups] of squares across [maxWidth], at most [maxSize] each. With
  /// [sizeFor], the squares are sized as if the row had that many letters, so
  /// words of different lengths share one square size; each word is centred.
  ///
  /// [breaks] (groups before each line break, as typed in the answer
  /// pattern) say where the row wraps when it does not fit on one line.
  factory TileLayout.of(
    List<int> groups,
    double maxWidth, {
    double maxSize = 56,
    int sizeFor = 0,
    List<int> breaks = const [],
  }) {
    if (breaks.isNotEmpty && maxWidth / _units(groups) < maxSize) {
      final split = splitAt(groups, breaks);
      final size = min(maxSize, maxWidth / split.map(_units).reduce(max));
      if (size >= minSize) return _place(split, size, maxWidth);
    }
    for (var lines = 1; lines <= max(1, groups.length); lines++) {
      final split = _split(groups, lines);
      final total = groups.fold<int>(0, (a, b) => a + b);
      final widest = max(
        split.map((g) => _units(g)).reduce(max),
        lines == 1 && sizeFor > total ? _units([sizeFor]) : 0.0,
      );
      final size = min(maxSize, maxWidth / widest);
      if (size >= minSize || lines == groups.length) return _place(split, size, maxWidth);
    }
    return _place([groups], min(maxSize, maxWidth / _units(groups)), maxWidth);
  }

  /// Squares plus the gaps: a little between squares, more between groups.
  static double _units(List<int> groups) {
    final squares = groups.fold<int>(0, (a, b) => a + b);
    return squares * 1.08 + (groups.length - 1) * 0.5;
  }

  static TileLayout _place(List<List<int>> lines, double size, double maxWidth) {
    final out = <Offset>[];
    final lineGap = size * 0.3;
    for (var l = 0; l < lines.length; l++) {
      final width = _units(lines[l]) * size - size * 0.08;
      var x = (maxWidth - width) / 2;
      final y = l * (size + lineGap);
      for (var g = 0; g < lines[l].length; g++) {
        for (var i = 0; i < lines[l][g]; i++) {
          out.add(Offset(x, y));
          x += size * 1.08;
        }
        x += size * 0.5;
      }
    }
    return TileLayout._(out, size, maxWidth, lines.length * size + (lines.length - 1) * lineGap);
  }

  /// [groups] broken into lines after each count of groups in [breaks].
  static List<List<int>> splitAt(List<int> groups, List<int> breaks) {
    final out = <List<int>>[];
    var from = 0;
    for (final b in [...breaks.where((b) => b > 0 && b < groups.length), groups.length]) {
      if (b > from) out.add(groups.sublist(from, b));
      from = max(from, b);
    }
    return out;
  }

  /// [groups] in [lines] runs of whole groups, as even as possible.
  static List<List<int>> _split(List<int> groups, int lines) {
    if (lines <= 1) return [groups];
    final total = groups.fold<int>(0, (a, b) => a + b);
    final out = <List<int>>[];
    var current = <int>[];
    var done = 0;
    for (final g in groups) {
      // Break before this group when stopping here lands nearer the line's
      // share than taking it would.
      final target = total * (out.length + 1) / lines;
      if (current.isNotEmpty && out.length < lines - 1 && (done - target).abs() <= (done + g - target).abs()) {
        out.add(current);
        current = [];
      }
      current.add(g);
      done += g;
    }
    if (current.isNotEmpty) out.add(current);
    return out;
  }

  /// Whether [point] is on a square, or within [slack] of one.
  bool hitsTile(Offset point, {double slack = 0}) {
    for (final p in positions) {
      if (Rect.fromLTWH(p.dx, p.dy, size, size).inflate(slack).contains(point)) return true;
    }
    return false;
  }

  /// The square nearest [point], on the same line when the row wraps.
  int nearest(Offset point) {
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < positions.length; i++) {
      final c = positions[i] + Offset(size / 2, size / 2);
      final d = (c.dx - point.dx).abs() + (c.dy - point.dy).abs() * 3;
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return best;
  }
}

/// One row of letter squares — a word or the final answer — played two ways
/// on the same letters:
///
/// * tap-to-form: tap letters in the order of the answer; each joins the
///   front, after those already formed (RAJA → tap A, J, A → AJAR). The
///   letter in the square the next one goes into blinks.
/// * drag: a letter dragged to a square is taken out and put back in there;
///   the letters between slide along — never a swap.
///
/// A drag only belongs to the row when it starts on a square; anywhere else
/// it is left to whatever holds the row, such as the page swipe.
class TileRow extends StatefulWidget {
  const TileRow({
    super.key,
    required this.row,
    required this.color,
    required this.groups,
    required this.formed,
    required this.enabled,
    required this.showCursor,
    required this.onTap,
    required this.onDrag,
    this.answerText,
    this.maxTile = 56,
    this.sizeFor = 0,
    this.semanticLabel,
    this.onMiss,
    this.shuffleTick = 0,
    this.lineBreaks = const [],
    this.hintTile,
    this.hintTick = 0,
    this.onFixed,
  });

  final RowState row;
  final Color color;
  final List<int> groups;

  /// Where the answer pattern wraps: groups before each line break.
  final List<int> lineBreaks;

  /// How many letters at the front the player has formed by tapping.
  final int formed;
  final bool enabled;

  /// Blink the letter in the square the next tapped letter goes into.
  final bool showCursor;

  /// A letter tapped: it joins the formed ones (or, if formed, takes the row back to it).
  final void Function(int index) onTap;

  /// A letter dragged from square [from] to square [to].
  final void Function(int from, int to) onDrag;

  /// The final answer as printed, for its quotes and apostrophes.
  final String? answerText;
  final double maxTile;

  /// Size the squares as if the row had this many letters, so a set of rows
  /// of different lengths share one square size.
  final int sizeFor;
  final String? semanticLabel;

  /// A tap on the row but off its squares: it picks the row, moves nothing.
  final VoidCallback? onMiss;

  /// Goes up each time the phone is shaken: the row jiggles and its letters
  /// slide slowly to their new places, so the reshuffle is seen.
  final int shuffleTick;

  /// The tile (pool index) a hint just placed in this row, and a count that
  /// goes up with each hint: the tile lifts, glows blue, glides into its
  /// square and settles.
  final int? hintTile;
  final int hintTick;

  /// A letter a hint fixed was tapped or dragged: it stays, and the player is told why.
  final VoidCallback? onFixed;

  /// How long a hinted letter glides; the game holds the Hint button as long.
  static const hintMove = Duration(milliseconds: 380);

  @override
  State<TileRow> createState() => _TileRowState();
}

class _TileRowState extends State<TileRow> with TickerProviderStateMixin {
  /// The jiggle after a shake.
  late final AnimationController _jiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  /// Letters glide (with a little bounce) rather than snap, just after a shake.
  bool _gliding = false;

  /// The blink of the letter in the next square to fill.
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
    lowerBound: 0.4,
  );

  /// A hinted letter on its way: lifted and glowing until it lands.
  late final AnimationController _hintGlow = AnimationController(vsync: this, duration: TileRow.hintMove);
  int? _hintPool;

  @override
  void initState() {
    super.initState();
    _syncBlink();
  }

  @override
  void didUpdateWidget(TileRow old) {
    super.didUpdateWidget(old);
    if (widget.shuffleTick != old.shuffleTick && _playable) {
      final still = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
      if (!still) {
        _gliding = true;
        _jiggle.forward(from: 0).whenComplete(() {
          if (mounted) setState(() => _gliding = false);
        });
      }
    }
    if (widget.hintTick != old.hintTick && widget.hintTile != null) {
      _hintPool = widget.hintTile;
      _hintGlow.forward(from: 0).whenComplete(() {
        if (mounted) setState(() => _hintPool = null);
      });
    }
    _syncBlink();
  }

  @override
  void dispose() {
    _hintGlow.dispose();
    _blink.dispose();
    _jiggle.dispose();
    super.dispose();
  }

  bool get _blinking => widget.showCursor && _playable && widget.formed < widget.row.length;

  void _syncBlink() {
    final still = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (_blinking && !still) {
      if (!_blink.isAnimating) _blink.repeat(reverse: true);
    } else {
      _blink.stop();
      _blink.value = 1;
    }
  }

  int? _dragFrom;
  int? _dragTo;
  Offset? _finger;
  int? _pressed;
  TileLayout? _layout;

  bool get _playable => widget.enabled && !widget.row.solved;

  /// Only drags that start on a square move a letter.
  bool _startsOnTile(Offset local) {
    final layout = _layout;
    return _playable && layout != null && layout.hitsTile(local, slack: layout.size * 0.15);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = TileLayout.of(
          widget.groups,
          constraints.maxWidth,
          maxSize: widget.maxTile,
          sizeFor: widget.sizeFor,
          breaks: widget.lineBreaks,
        );
        if (layout.positions.length != widget.row.length) return const SizedBox.shrink();
        _layout = layout;
        final multiLine = layout.positions.any((o) => o.dy > 0);
        final order = _previewOrder();
        final letters = widget.row.letters;

        final tiles = <Widget>[];
        for (var square = 0; square < order.length; square++) {
          final poolIndex = order[square];
          final dragging = _dragFrom != null && poolIndex == widget.row.order[_dragFrom!];
          var pos = layout.positions[square];
          if (dragging && _finger != null) {
            // A wrapped row lets the letter travel between lines with the finger.
            final dy = multiLine ? _finger!.dy - layout.size / 2 : pos.dy - layout.size * 0.12;
            pos = Offset(_finger!.dx - layout.size / 2, dy);
          }
          final letter = widget.row.pool[poolIndex];
          final hinting = _hintPool != null;
          final hinted = poolIndex == _hintPool;
          tiles.add(
            AnimatedPositioned(
              key: ValueKey(poolIndex),
              // A hint's letter and the ones it pushes along move together, slower
              // than a tap's, so the help is seen.
              duration: dragging
                  ? Duration.zero
                  : (hinting ? TileRow.hintMove : Duration(milliseconds: _gliding ? 480 : 180)),
              curve: _gliding || hinted ? Curves.easeOutBack : Curves.easeOutCubic,
              left: pos.dx,
              top: pos.dy,
              width: layout.size,
              height: layout.size,
              child: _Tile(
                letter: letter,
                size: layout.size,
                color: widget.color,
                circled: square < widget.row.circles.length && widget.row.circles[square],
                blink: _blinking && _dragFrom == null && square == widget.formed ? _blink : null,
                solved: widget.row.solved,
                lifted: dragging || hinted,
                glow: hinted,
                fixed: widget.row.fixed.contains(square) && !widget.row.solved,
                pressed: _pressed == square && _dragFrom == null,
              ),
            ),
          );
        }

        final children = <Widget>[...tiles];
        if (widget.answerText != null) children.addAll(_marks(layout, p));

        void onStart(Offset local) {
          final i = layout.nearest(local);
          if (letters[i] == ' ') return;
          // A letter a hint put right stays where it is.
          if (widget.row.fixed.contains(i)) {
            widget.onFixed?.call();
            return;
          }
          setState(() {
            _dragFrom = i;
            _dragTo = i;
            _finger = local;
            _pressed = null;
          });
        }

        void onUpdate(Offset local) {
          if (_dragFrom == null) return;
          final to = layout.nearest(multiLine ? local : Offset(local.dx, layout.positions[_dragFrom!].dy));
          if (to != _dragTo) HapticFeedback.selectionClick();
          setState(() {
            _dragTo = to;
            _finger = local;
          });
        }

        // A letter drag must claim the finger before the page swipe or scroll
        // does, which wait for the device's full touch slop (about 8 on
        // Android). A pan waits for twice its touch slop, so a quarter of the
        // device's makes it start at half the distance. Left at Flutter's
        // default (18, so 36 for a pan) it lost and the letter did not move.
        final device = MediaQuery.maybeGestureSettingsOf(context)?.touchSlop ?? kTouchSlop;
        final eager = DeviceGestureSettings(touchSlop: device / 4);

        // Any direction, so a slanted swipe on a letter is still a letter
        // drag, never the page's scroll.
        final drag = <Type, GestureRecognizerFactory>{
          _TilePan: GestureRecognizerFactoryWithHandlers<_TilePan>(
            // From where the finger went down, not where the drag was recognised.
            () => _TilePan(debugOwner: this)..dragStartBehavior = DragStartBehavior.down,
            (r) => r
              ..gestureSettings = eager
              ..startsOnTile = _startsOnTile
              ..onStart = ((d) => onStart(d.localPosition))
              ..onUpdate = ((d) => onUpdate(d.localPosition))
              ..onEnd = ((_) => _endDrag(commit: true))
              ..onCancel = (() => _endDrag(commit: false)),
          ),
        };

        // Below the squares: their depth.
        final depthRoom = layout.size * 0.16;
        return Semantics(
          label: widget.semanticLabel,
          value: [
            for (var i = 0; i < letters.length; i++)
              letters[i] == ' '
                  ? 'blank'
                  : '${letters[i]}${widget.row.fixed.contains(i) ? ', fixed by a hint' : (i < widget.formed ? ', formed' : (i == widget.formed && _blinking ? ', next' : ''))}',
          ].join(', '),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _playable
                ? (d) {
                    final i = layout.nearest(d.localPosition);
                    if (letters[i] != ' ' && layout.hitsTile(d.localPosition, slack: layout.size * 0.15)) {
                      setState(() => _pressed = i);
                    }
                  }
                : null,
            onTapCancel: () => setState(() => _pressed = null),
            onTapUp: _playable
                ? (d) {
                    setState(() => _pressed = null);
                    final i = layout.nearest(d.localPosition);
                    if (letters[i] == ' ' || !layout.hitsTile(d.localPosition, slack: layout.size * 0.15)) {
                      widget.onMiss?.call();
                      return;
                    }
                    if (widget.row.fixed.contains(i)) {
                      widget.onMiss?.call();
                      widget.onFixed?.call();
                      return;
                    }
                    HapticFeedback.lightImpact();
                    widget.onTap(i);
                  }
                : null,
            child: RawGestureDetector(
              gestures: drag,
              behavior: HitTestBehavior.translucent,
              child: SizedBox(
                width: layout.width,
                height: layout.height + depthRoom,
                child: AnimatedBuilder(
                  animation: _jiggle,
                  // A few quick side-to-side shakes that settle, like a shaken tray.
                  builder: (_, child) {
                    final t = _jiggle.value;
                    final dx = t == 0 || t == 1 ? 0.0 : sin(t * pi * 6) * (1 - t) * layout.size * 0.18;
                    return Transform.translate(offset: Offset(dx, 0), child: child);
                  },
                  child: Stack(clipBehavior: Clip.none, children: children),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// The order shown while dragging: the letter already where it would land.
  List<int> _previewOrder() {
    final from = _dragFrom, to = _dragTo;
    if (from == null || to == null) return widget.row.order;
    return widget.row.movedAround(from, to);
  }

  void _endDrag({required bool commit}) {
    final from = _dragFrom, to = _dragTo;
    setState(() => _dragFrom = _dragTo = _finger = _pressed = null);
    if (commit && from != null && to != null && from != to) widget.onDrag(from, to);
  }

  List<Widget> _marks(TileLayout layout, Palette p) {
    final shape = AnswerShape.of(widget.answerText!);
    if (shape.letters != layout.positions.length) return const [];
    final w = layout.size * 0.4;
    return [
      for (final m in shape.marks)
        Positioned(
          left: m.before ? layout.positions[m.index].dx - w - 1 : layout.positions[m.index].dx + layout.size + 1,
          top: layout.positions[m.index].dy - layout.size * 0.12,
          width: w,
          child: IgnorePointer(
            child: Text(
              m.text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: layout.size * 0.62, fontWeight: FontWeight.w700, color: p.ink, height: 1),
            ),
          ),
        ),
    ];
  }
}

/// A drag in any direction that only claims pointers landing on a square.
class _TilePan extends PanGestureRecognizer {
  _TilePan({super.debugOwner});
  bool Function(Offset local) startsOnTile = _always;

  @override
  bool isPointerAllowed(PointerEvent event) => startsOnTile(event.localPosition) && super.isPointerAllowed(event);
}

bool _always(Offset _) => true;

class _Tile extends StatelessWidget {
  const _Tile({
    required this.letter,
    required this.size,
    required this.color,
    required this.circled,
    this.blink,
    required this.solved,
    required this.lifted,
    required this.pressed,
    this.glow = false,
    this.fixed = false,
  });

  final String letter;

  /// A hint's letter on its way: a soft BluJem-blue glow, only while it moves.
  final bool glow;

  /// Put right by a hint: a small mark says it will not move.
  final bool fixed;
  final double size;
  final Color color;
  final bool circled;

  /// Fades the letter in and out: the next square to fill.
  final Animation<double>? blink;
  final bool solved;
  final bool lifted;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final empty = letter == ' ';
    // Plain until the whole word is right, then filled with the row's colour:
    // colour means solved, never just "moved".
    final face = empty ? p.sunken : (solved ? color : p.tile);
    // The next square to fill is marked in BluJem blue: its edge, and its
    // letter pulsing between blue and soft blue.
    final next = blink != null && !empty;
    final edge = empty
        ? p.sunken
        : next
        ? p.cursor
        : Color.lerp(color, p.ink, solved ? 0.35 : 0.25)!;
    final radius = BorderRadius.circular(size * 0.22);
    // Pressed sinks into its edge; lifted rises off the board.
    final depth = lifted ? 6.0 : (pressed ? 1.0 : 3.0);

    return AnimatedScale(
      scale: lifted ? 1.12 : (pressed ? 0.92 : 1),
      duration: Duration(milliseconds: pressed ? 60 : 140),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: face,
          borderRadius: radius,
          border: Border.all(color: empty ? p.rule : edge, width: empty ? 1.5 : 2),
          boxShadow: empty
              ? null
              : [
                  BoxShadow(color: edge, offset: Offset(0, depth)),
                  if (lifted)
                    BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 8)),
                  if (glow) BoxShadow(color: p.cursor.withValues(alpha: 0.55), blurRadius: 16, spreadRadius: 2),
                ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // A circled letter, as printed: a dark circle inside the square.
            if (circled)
              Container(
                width: size * 0.8,
                height: size * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: p.ink.withValues(alpha: 0.75), width: 1.8),
                ),
              ),
            if (fixed)
              Positioned(
                top: size * 0.09,
                right: size * 0.09,
                child: Container(
                  width: size * 0.11,
                  height: size * 0.11,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: p.inkSoft.withValues(alpha: 0.7)),
                ),
              ),
            if (!empty)
              FadeTransition(
                opacity: blink ?? kAlwaysCompleteAnimation,
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: size * 0.54,
                    fontWeight: FontWeight.w700,
                    color: next ? p.cursor : p.ink,
                    height: 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
