import 'package:flutter/material.dart';
import '../core/constants/palette.dart';
import '../core/constants/colors.dart';
import '../core/constants/typography.dart';
import '../core/models/domain_models.dart';

class LifecycleRail extends StatelessWidget {
  final TokenState state;
  final bool isFinanced;

  const LifecycleRail({
    super.key,
    required this.state,
    this.isFinanced = false,
  });

  @override
  Widget build(BuildContext context) {
    final steps = [
      {'id': TokenState.created, 'label': 'Created'},
      {'id': TokenState.delivered, 'label': 'Delivered'},
      {'id': TokenState.financed, 'label': 'Financed'},
      {'id': TokenState.settled, 'label': 'Settled'},
    ];

    int activeIndex = 0;
    if (state == TokenState.settled) {
      activeIndex = 3;
    } else if (state == TokenState.financed || isFinanced) {
      activeIndex = 2;
    } else if (state == TokenState.delivered || state == TokenState.partiallyFulfilled) {
      activeIndex = 1;
    }

    final isDisputed = state == TokenState.disputed;

    // This rail sits on a dark portal card and on a light field card. Ask the
    // ambient theme which, rather than assuming the field palette.
    final surface = context.lamp;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: surface.surfaceAlt,
        borderRadius: BorderRadius.circular(LaMPRadius.card),
        border: Border.all(color: surface.line),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < steps.length; i++) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= activeIndex
                          ? (isDisputed && i == activeIndex ? LaMPColors.dispute : LaMPColors.verified)
                          : surface.surfaceSunken,
                      border: Border.all(
                        color: i == activeIndex ? LaMPColors.brand : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: i < activeIndex
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: i <= activeIndex ? Colors.white : surface.inkFaint,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    steps[i]['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: i == activeIndex ? FontWeight.bold : FontWeight.w500,
                      color: i <= activeIndex ? surface.ink : surface.inkFaint,
                    ),
                  ),
                ],
              ),
              if (i < steps.length - 1)
                Container(
                  width: 24,
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: i < activeIndex ? LaMPColors.verified : surface.surfaceSunken,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
