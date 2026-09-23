import 'package:flutter/material.dart';

class DataMatrixView extends StatelessWidget {
  final String text;
  final double size;

  const DataMatrixView({
    super.key,
    required this.text,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white, // design-lint: allow (a barcode must be black on white to scan)
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black12), // design-lint: allow (a barcode must be black on white to scan)
      ),
      child: CustomPaint(
        painter: _DataMatrixPainter(seed: text.hashCode),
      ),
    );
  }
}

class _DataMatrixPainter extends CustomPainter {
  final int seed;

  _DataMatrixPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final paintBlack = Paint()..color = Colors.black; // design-lint: allow (a barcode must be black on white to scan)
    const grid = 12;
    final cell = size.width / grid;

    // Draw L-finder border (left and bottom solid)
    for (int i = 0; i < grid; i++) {
      canvas.drawRect(Rect.fromLTWH(0, i * cell, cell, cell), paintBlack);
      canvas.drawRect(Rect.fromLTWH(i * cell, (grid - 1) * cell, cell, cell), paintBlack);
    }

    // Top and right alternating clock track
    for (int i = 0; i < grid; i += 2) {
      canvas.drawRect(Rect.fromLTWH(i * cell, 0, cell, cell), paintBlack);
      canvas.drawRect(Rect.fromLTWH((grid - 1) * cell, i * cell, cell, cell), paintBlack);
    }

    // Inner pseudo-random deterministic matrix pattern
    var rng = seed;
    for (int r = 1; r < grid - 1; r++) {
      for (int c = 1; c < grid - 1; c++) {
        rng = (rng * 1103515245 + 12345) & 0x7FFFFFFF;
        if ((rng % 3) == 0) {
          canvas.drawRect(Rect.fromLTWH(c * cell, r * cell, cell, cell), paintBlack);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DataMatrixPainter oldDelegate) =>
      oldDelegate.seed != seed;
}
