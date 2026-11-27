import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Whether the player asked for less motion.
bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// One short fall of paper confetti in the sheet's row colours, for a solved
/// puzzle. Plays once and never takes a touch.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key});

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
    ..forward();
  final _pieces = List.generate(70, (i) => _Piece(Random(i * 7919)));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return const SizedBox.shrink();
    final p = context.palette;
    final colors = [...p.rows, p.accent, p.success];
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_pieces, _c.value, colors)),
      ),
    );
  }
}

class _Piece {
  _Piece(Random r)
    : x = r.nextDouble(),
      drift = (r.nextDouble() - 0.5) * 0.3,
      speed = 0.7 + r.nextDouble() * 0.6,
      delay = r.nextDouble() * 0.25,
      spin = (r.nextDouble() - 0.5) * 12,
      size = 6 + r.nextDouble() * 6,
      color = r.nextInt(6);
  final double x, drift, speed, delay, spin, size;
  final int color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t, this.colors);
  final List<_Piece> pieces;
  final double t;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      final local = ((t - piece.delay) / (1 - piece.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final fade = local > 0.75 ? (1 - local) / 0.25 : 1.0;
      final x = (piece.x + piece.drift * local) * size.width;
      final y = -20 + local * local * piece.speed * size.height;
      final paint = Paint()..color = colors[piece.color % colors.length].withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(piece.spin * local);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: piece.size, height: piece.size * 0.55),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// The words solved so far as small dots: ● ● ○ ○.
class WordProgress extends StatelessWidget {
  const WordProgress({super.key, required this.solved});

  /// One flag per word, in order.
  final List<bool> solved;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final done = solved.where((s) => s).length;
    return Semantics(
      label: '$done of ${solved.length} words solved',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < solved.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: AnimatedScale(
                  scale: solved[i] ? 1 : 0.85,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: solved[i] ? p.rowColor(i) : Colors.transparent,
                      border: Border.all(
                        color: solved[i] ? Color.lerp(p.rowColor(i), p.ink, 0.45)! : p.inkFaint,
                        width: 1.6,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "See Cartoon ›" or "‹ See Words": a small label that turns the page, and
/// whose chevron nudges toward the swipe until the player has found it.
class PagerHint extends StatelessWidget {
  const PagerHint({super.key, required this.label, required this.forward, required this.nudge, required this.onTap});
  final String label;

  /// Points right (on to the words) rather than left (back to the cartoon).
  final bool forward;
  final bool nudge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final chevron = Icon(forward ? Icons.chevron_right_rounded : Icons.chevron_left_rounded, size: 22, color: p.ink);
    final moving = nudge && !reduceMotion(context)
        ? TweenAnimationBuilder<double>(
            key: ValueKey(label),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1400),
            builder: (_, t, child) => Transform.translate(
              // Two small pushes toward the swipe, then still.
              offset: Offset((forward ? 1 : -1) * 5 * sin(t * 2 * pi * 2).abs() * (1 - t), 0),
              child: child,
            ),
            child: chevron,
          )
        : chevron;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: p.card,
        shape: StadiumBorder(side: BorderSide(color: p.rule)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(forward ? 12 : 4, 4, forward ? 4 : 12, 4),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!forward) moving,
                  Text(
                    label,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: p.ink),
                  ),
                  if (forward) moving,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round arrow over the cartoon that keeps pulsing toward the words page,
/// saying the jumbled words are a swipe away. Tapping it turns the page too.
class SwipeArrow extends StatefulWidget {
  const SwipeArrow({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<SwipeArrow> createState() => _SwipeArrowState();
}

class _SwipeArrowState extends State<SwipeArrow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) {
            final t = Curves.easeInOut.transform(_c.value);
            return Transform.translate(
              offset: Offset(8 * t, 0),
              child: Transform.scale(scale: 1 + .12 * t, child: child),
            );
          },
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: p.accent,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: p.accent.withValues(alpha: .45), blurRadius: 14, spreadRadius: 1)],
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.card.withValues(alpha: .92),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: p.rule),
                  ),
                  child: Text(
                    widget.label,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: p.ink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
