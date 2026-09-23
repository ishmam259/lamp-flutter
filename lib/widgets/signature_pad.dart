import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/constants/palette.dart';
import '../core/constants/typography.dart';

class SignaturePad extends StatefulWidget {
  final ValueChanged<bool> onSigned;
  final VoidCallback? onClear;
  final double height;

  const SignaturePad({
    super.key,
    required this.onSigned,
    this.onClear,
    this.height = 140,
  });

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final List<Offset?> _points = [];

  void _clear() {
    setState(() {
      _points.clear();
    });
    widget.onSigned(false);
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            // The pad follows the palette. It was hard-coded white while the
            // stroke is painted with `c.ink`, so in the dark field theme the
            // signature was near-white ink on a white pad — invisible as it
            // was being drawn, on the one screen where seeing it is the point.
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.lineStrong),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: GestureDetector(
              onPanStart: (details) {
                setState(() {
                  _points.add(details.localPosition);
                });
                widget.onSigned(true);
              },
              onPanUpdate: (details) {
                setState(() {
                  _points.add(details.localPosition);
                });
              },
              onPanEnd: (details) {
                setState(() {
                  _points.add(null);
                });
              },
              child: CustomPaint(
                painter: _SignaturePainter(points: _points, inkColor: context.lamp.ink),
                size: Size.infinite,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Flexes, so the clear button keeps its width and the caption
            // shortens rather than pushing it off the pad.
            Expanded(
              child: Text(
                'Sign above',
                style: LaMPType.caption.copyWith(color: c.inkFaint),
              ),
            ),
            TextButton(
              onPressed: _points.isEmpty ? null : _clear,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Clear'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  final Color inkColor;

  _SignaturePainter({required this.points, required this.inkColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = inkColor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.5;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      } else if (points[i] != null && points[i + 1] == null) {
        canvas.drawPoints(ui.PointMode.points, [points[i]!], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
