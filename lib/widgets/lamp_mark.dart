import 'package:flutter/material.dart';

/// The official LaMP brand mark / logo widget.
/// Matches components/lamp-mark.tsx in the React app.
///
/// Brightness-aware: the dark variant is a mint gradient, the light variant a
/// deep-green one. [mono] is pure white, for coloured or photo grounds.
/// Don't set it below 32dp — the cubes and the shield blur together.
class LampMark extends StatelessWidget {
  final double size;
  final bool markOnly;
  final bool mono;

  const LampMark({
    super.key,
    this.size = 38,
    this.markOnly = true,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final String path = mono
        ? 'assets/images/logo-mark-white.png'
        : markOnly
            ? (dark ? 'assets/images/logo-mark-dark.png' : 'assets/images/logo-mark-light.png')
            : (dark ? 'assets/images/logo-full-dark.png' : 'assets/images/logo-full-light.png');
    return Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}
