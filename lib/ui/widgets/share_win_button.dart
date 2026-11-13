import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/game_controller.dart';
import '../share_card.dart';
import '../theme.dart' show fontFamily;
import 'celebration.dart';

/// "Share your win", dressed like a game reward: a raised blue gem of a
/// button with a gold trophy that wiggles, a shine that sweeps across it and
/// a couple of twinkling sparkles. It sinks when pressed, like the tiles.
class ShareWinButton extends StatefulWidget {
  const ShareWinButton({super.key, required this.game});
  final GameController game;

  @override
  State<ShareWinButton> createState() => _ShareWinButtonState();
}

class _ShareWinButtonState extends State<ShareWinButton> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
  bool _pressed = false;
  bool _busy = false;

  static const _face = [Color(0xFF4C9BFF), Color(0xFF1E6FE0), Color(0xFF5B45F0)];
  static const _edge = Color(0xFF173F9E);
  static const _depth = 6.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    await shareWin(context, widget.game);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final sink = _pressed ? _depth - 2 : 0.0;
    return Semantics(
      button: true,
      label: 'Share your win',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: _share,
        child: SizedBox(
          height: 66 + _depth,
          child: Stack(
            children: [
              // The edge under the face, which the face sinks onto.
              Positioned.fill(
                top: _depth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _edge,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: _edge.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6)),
                    ],
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 80),
                left: 0,
                right: 0,
                top: sink,
                height: 66,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedBuilder(
                    animation: _loop,
                    builder: (context, _) => CustomPaint(
                      foregroundPainter: _ShinePainter(_loop.value),
                      child: _content(context, _loop.value),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, double t) {
    // A quick wiggle at the start of each loop, then still.
    final wiggle = t < 0.18 ? sin(t / 0.18 * pi * 3) * 0.14 : 0.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: _face, begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Transform.rotate(
              angle: wiggle,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFFFFE58A), Color(0xFFE8C547), Color(0xFFC79A1E)],
                    stops: [0, 0.6, 1],
                    center: Alignment(-0.3, -0.4),
                  ),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.emoji_events_rounded, color: Color(0xFF6B4A00), size: 26),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SHARE YOUR WIN',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      letterSpacing: 1.2,
                      color: Colors.white,
                      shadows: [Shadow(color: Color(0x55000000), offset: Offset(0, 2), blurRadius: 2)],
                    ),
                  ),
                  Text(
                    'Brag card with your answer + QR',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.2)),
              child: _busy
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Icon(Icons.ios_share_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// The shine that sweeps across the button, and two sparkles that twinkle.
class _ShinePainter extends CustomPainter {
  _ShinePainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // The shine crosses in the middle of each loop.
    const from = 0.3, to = 0.7;
    if (t > from && t < to) {
      final x = -0.3 * size.width + (t - from) / (to - from) * 1.6 * size.width;
      final band = Path()
        ..moveTo(x, 0)
        ..lineTo(x + 34, 0)
        ..lineTo(x + 34 - size.height * 0.6, size.height)
        ..lineTo(x - size.height * 0.6, size.height)
        ..close();
      canvas.drawPath(band, Paint()..color = Colors.white.withValues(alpha: 0.28));
    }
    _sparkle(canvas, Offset(size.width - 62, 12), 5, sin(t * 2 * pi));
    _sparkle(canvas, Offset(size.width * 0.62, size.height - 11), 4, sin(t * 2 * pi + 2.2));
  }

  /// A four-pointed star, shown while [phase] is above zero.
  void _sparkle(Canvas canvas, Offset c, double r, double phase) {
    if (phase <= 0) return;
    final s = r * phase;
    final star = Path()
      ..moveTo(c.dx, c.dy - s * 2)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + s * 2, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s * 2)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - s * 2, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s * 2)
      ..close();
    canvas.drawPath(star, Paint()..color = Colors.white.withValues(alpha: 0.9 * phase));
  }

  @override
  bool shouldRepaint(_ShinePainter old) => old.t != t;
}
