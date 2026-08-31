import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A loading indicator drawn as a tea cup that keeps filling with chai.
///
/// One repeating controller drives both the rising level and the wavy
/// surface; the chai fades out over the last fraction of the loop so the
/// restart back to an empty cup is invisible.
class ChaiCupLoader extends StatefulWidget {
  const ChaiCupLoader({
    super.key,
    this.size = 96,
    this.cupColor,
    this.teaColor,
  });

  final double size;

  /// Cup outline / handle / saucer colour. Defaults to `onSurface`.
  final Color? cupColor;

  /// The chai. Defaults to a warm milky-brown.
  final Color? teaColor;

  @override
  State<ChaiCupLoader> createState() => _ChaiCupLoaderState();
}

class _ChaiCupLoaderState extends State<ChaiCupLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: widget.size,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(
            painter: _CupPainter(
              t: _c.value,
              cupColor: widget.cupColor ?? scheme.onSurface,
              teaColor: widget.teaColor ?? const Color(0xFFC8802B),
            ),
          ),
        ),
      ),
    );
  }
}

class _CupPainter extends CustomPainter {
  _CupPainter({
    required this.t,
    required this.cupColor,
    required this.teaColor,
  });

  /// Loop position, 0..1.
  final double t;
  final Color cupColor;
  final Color teaColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = cupColor;

    // --- cup body: a slightly tapered cup with a rounded bottom -------------
    final bodyTop = h * 0.30;
    final bodyBot = h * 0.82;
    final body = Path()
      ..moveTo(w * 0.20, bodyTop)
      ..lineTo(w * 0.72, bodyTop)
      ..lineTo(w * 0.63, bodyBot)
      ..quadraticBezierTo(w * 0.46, bodyBot + h * 0.06, w * 0.29, bodyBot)
      ..close();

    // --- chai: rising level + wavy surface, clipped to the cup -------------
    final rise = Curves.easeInOut.transform((t / 0.72).clamp(0.0, 1.0));
    final fade = t < 0.86 ? 1.0 : (1.0 - (t - 0.86) / 0.14).clamp(0.0, 1.0);
    final innerTop = bodyTop + h * 0.05;
    final innerBot = bodyBot - h * 0.01;
    final surfaceY = innerBot - rise * (innerBot - innerTop);
    final amp = h * 0.014;
    final phase = t * math.pi * 4; // 2 full wave cycles per loop => seamless

    final wave = Path()..moveTo(0, h);
    for (double x = 0; x <= w; x += 2) {
      final y = surfaceY +
          math.sin(x / w * 2 * math.pi * 1.6 + phase) * amp;
      wave.lineTo(x, y);
    }
    wave
      ..lineTo(w, h)
      ..close();

    canvas.save();
    canvas.clipPath(body);
    canvas.drawPath(
      wave,
      Paint()
        ..style = PaintingStyle.fill
        ..color = teaColor.withValues(alpha: fade),
    );
    canvas.restore();

    // --- handle, body outline, saucer -----------------------------------
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.72, h * 0.40)
        ..cubicTo(w * 0.96, h * 0.40, w * 0.96, h * 0.67, w * 0.66, h * 0.66),
      stroke,
    );
    canvas.drawPath(body, stroke);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.46, h * 0.90),
        width: w * 0.66,
        height: h * 0.11,
      ),
      0,
      math.pi,
      false,
      stroke,
    );

    // --- two curling wisps of steam -----------------------------------
    final steam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.028
      ..strokeCap = StrokeCap.round
      ..color = cupColor.withValues(alpha: 0.30);
    for (final sx in [w * 0.37, w * 0.53]) {
      final wisp = Path()..moveTo(sx, h * 0.27);
      for (double i = 0.0; i <= 1.0; i += 0.1) {
        wisp.lineTo(
          sx + math.sin(i * math.pi * 2 + t * math.pi * 2) * w * 0.03,
          h * 0.27 - i * h * 0.17,
        );
      }
      canvas.drawPath(wisp, steam);
    }
  }

  @override
  bool shouldRepaint(_CupPainter old) =>
      old.t != t || old.cupColor != cupColor || old.teaColor != teaColor;
}
