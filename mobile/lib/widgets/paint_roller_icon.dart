import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Custom paint-roller glyph — yellow roller head with ink frame + handle.
/// 24×24 canvas per style-guide Paint FAB spec.
class PaintRollerIcon extends StatelessWidget {
  const PaintRollerIcon({super.key, this.size = 24, this.disabled = false});

  final double size;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PaintRollerPainter(disabled: disabled),
      ),
    );
  }
}

class _PaintRollerPainter extends CustomPainter {
  _PaintRollerPainter({required this.disabled});

  final bool disabled;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    final ink = disabled ? BbbColors.inkFaint : BbbColors.ink;
    final yellow = disabled
        ? BbbColors.accentYellow.withValues(alpha: 0.45)
        : BbbColors.accentYellow;
    final strokeW = 1.6 * scale;

    // Roller head — rect(3,4 14×5 rx=1.2), yellow fill, ink stroke 1.6.
    final headRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(3 * scale, 4 * scale, 14 * scale, 5 * scale),
      Radius.circular(1.2 * scale),
    );
    canvas.drawRRect(headRect, Paint()..color = yellow);
    canvas.drawRRect(
      headRect,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeJoin = StrokeJoin.round,
    );

    // Frame — short bracket down from the head center to the handle bend.
    final framePaint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final framePath = Path()
      ..moveTo(10 * scale, 9 * scale)
      ..lineTo(10 * scale, 11.5 * scale)
      ..lineTo(13 * scale, 11.5 * scale);
    canvas.drawPath(framePath, framePaint);

    // Handle — angled down-right from frame bend.
    final handlePath = Path()
      ..moveTo(13 * scale, 11.5 * scale)
      ..lineTo(13 * scale, 20 * scale);
    canvas.drawPath(handlePath, framePaint);
  }

  @override
  bool shouldRepaint(covariant _PaintRollerPainter old) =>
      old.disabled != disabled;
}
