import 'package:flutter/material.dart';
import '../core/constants/colors.dart';
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
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
                          : Colors.black12,
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
                                color: i <= activeIndex ? Colors.white : Colors.black45,
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
                      color: i <= activeIndex ? LaMPColors.fieldInk : Colors.black38,
                    ),
                  ),
                ],
              ),
              if (i < steps.length - 1)
                Container(
                  width: 24,
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: i < activeIndex ? LaMPColors.verified : Colors.black12,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
