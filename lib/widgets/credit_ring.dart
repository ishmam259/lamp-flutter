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
                // Tokens rather than a fraction of the ring: at 120dp the
                // caption scaled to 9.6px, under the 11px floor.
                style: (size >= 140 ? LaMPType.displayFigure : LaMPType.figure)
                    .copyWith(color: c.ink, height: 1.0),
              ),
              const SizedBox(height: 2),
              Text(
                'OF $total',
                style: LaMPType.label.copyWith(color: c.inkFaint),
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

    // One arc per cycle, and the gaps have to survive the stroke: round caps
    // reach half a stroke past each end and closed the old 0.08rad gaps, so
    // eight cycles read as one ring. Butt caps, and a gap sized to the stroke.
    final gapRadians = (strokeWidth * 0.9) / radius;
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
        ..strokeCap = StrokeCap.butt;

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
