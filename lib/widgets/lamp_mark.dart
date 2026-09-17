import 'package:flutter/material.dart';

/// The official LaMP brand mark / logo widget.
/// Matches components/lamp-mark.tsx in the React app.
class LampMark extends StatelessWidget {
  final double size;
  final bool markOnly;

  const LampMark({
    super.key,
    this.size = 28,
    this.markOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      markOnly ? 'assets/images/logo-mark.png' : 'assets/images/logo-removebg-preview.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}
