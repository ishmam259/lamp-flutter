import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/constants/palette.dart';
import '../core/models/domain_models.dart';
import '../core/constants/typography.dart';

class CreditRing extends StatelessWidget {
  final List<CreditCycle> cycles;
  final RecourseTier tier;
  final double size;
  final double strokeWidth;

  const CreditRing({
    super.key,
    required this.cycles,
    required this.tier,
    this.size = 152,
    this.strokeWidth = 10,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    final target = tier.cyclesToNext ?? cycles.length;
    final total = math.max(target, math.max(cycles.length, 1));

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _CreditRingPainter(
              onTimeColor: c.verified,
              lateColor: c.pending,
              trackColor: c.surfaceSunken,
              cycles: cycles,
              total: total,
              strokeWidth: strokeWidth,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${cycles.length}',
                style: TextStyle(
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.bold,
                  fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback,
                  color: c.ink,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'of $total cycles',
                style: TextStyle(
                  fontSize: size * 0.08,
                  fontWeight: FontWeight.w600,
                  color: c.inkFaint,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreditRingPainter extends CustomPainter {
  final List<CreditCycle> cycles;
  final int total;
  final double strokeWidth;
  final Color onTimeColor;
  final Color lateColor;
  final Color trackColor;

  _CreditRingPainter({
    required this.onTimeColor,
    required this.lateColor,
    required this.trackColor,
    required this.cycles,
    required this.total,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    const gapRadians = 0.08;
    final totalGap = gapRadians * total;
    final segmentRadians = (2 * math.pi - totalGap) / total;

    // Start from top (-pi / 2)
    var currentAngle = -math.pi / 2;

    for (int i = 0; i < total; i++) {
      Color arcColor;
      if (i < cycles.length) {
        arcColor = cycles[i].onTime ? onTimeColor : lateColor;
      } else {
        arcColor = trackColor;
      }

      final paint = Paint()
        ..color = arcColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle,
        segmentRadians,
        false,
        paint,
      );

      currentAngle += segmentRadians + gapRadians;
    }
  }

  @override
  bool shouldRepaint(covariant _CreditRingPainter oldDelegate) {
    return oldDelegate.cycles.length != cycles.length ||
        oldDelegate.total != total ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
