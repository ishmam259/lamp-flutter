import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/palette.dart';
import '../core/state/theme_controller.dart';

/// Cycles light → dark → follow the phone.
///
/// The icon shows the mode that is *in force*, not the one a tap would move to,
/// and the tooltip names it — an icon alone cannot distinguish "dark because
/// you chose dark" from "dark because your phone is".
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    final c = context.lamp;

    return IconButton(
      tooltip: 'Theme — ${controller.label}',
      icon: Icon(controller.icon, color: c.inkMuted),
      onPressed: () async {
        await controller.cycle();
        if (!context.mounted) return;
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(
          SnackBar(
            content: Text('Theme: ${controller.label.toLowerCase()}'),
            duration: const Duration(milliseconds: 1200),
          ),
        );
      },
    );
  }
}
