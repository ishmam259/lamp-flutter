import 'package:flutter/material.dart';
import '../core/constants/palette.dart';
import '../core/constants/typography.dart';
import '../core/models/domain_models.dart';

class LifecycleRail extends StatelessWidget {
  final TokenState state;
  final bool isFinanced;
  /// Whether the off-chain PDF has been anchored on the channel. Drives the
  /// 5th "Anchored" stage between Financed and Settled.
  final bool isDocumentAnchored;

  const LifecycleRail({
    super.key,
    required this.state,
    this.isFinanced = false,
    this.isDocumentAnchored = false,
  });

  @override
  Widget build(BuildContext context) {
    final steps = [
      {'id': TokenState.created, 'label': 'Created'},
      {'id': TokenState.delivered, 'label': 'Delivered'},
      {'id': TokenState.financed, 'label': 'Financed'},
      {'id': 'anchored', 'label': 'Anchored'},
      {'id': TokenState.settled, 'label': 'Settled'},
    ];

    int activeIndex = 0;
    if (state == TokenState.settled) {
      activeIndex = 4;
    } else if (state == TokenState.financed || isFinanced) {
      // Financed advances one step when the document has been anchored.
      activeIndex = isDocumentAnchored ? 3 : 2;
    } else if (state == TokenState.delivered || state == TokenState.partiallyFulfilled) {
      activeIndex = 1;
    }

    final isDisputed = state == TokenState.disputed;

    // This rail sits on a dark portal card and on a light field card. Ask the
    // ambient theme which, rather than assuming the field palette.
    final surface = context.lamp;

    // A connector reads as done once the step it leads out of is reached.
    Widget link(bool done) => Container(
          height: 2,
          color: done ? surface.verified : surface.surfaceSunken,
        );

    // Five equal columns, each a numbered dot over its label, joined by lines
    // through the dots. The old rail was a horizontal scroller that clipped
    // the last steps ("3 Fi") with no hint that it scrolled; this one always
    // fits the card, so nothing is hidden.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        color: surface.surfaceAlt,
        borderRadius: BorderRadius.circular(LaMPRadius.card),
        border: Border.all(color: surface.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < steps.length; i++)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 26,
                    child: Row(
                      children: [
                        Expanded(
                          child: i == 0
                              ? const SizedBox.shrink()
                              : link(i <= activeIndex),
                        ),
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i <= activeIndex
                                ? (isDisputed && i == activeIndex ? surface.dispute : surface.verified)
                                : surface.surfaceSunken,
                            border: Border.all(
                              color: i == activeIndex ? surface.brand : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: i < activeIndex
                                ? Icon(Icons.check, size: 14, color: surface.onBrand)
                                : Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: i <= activeIndex ? surface.onBrand : surface.inkFaint,
                                    ),
                                  ),
                          ),
                        ),
                        Expanded(
                          child: i == steps.length - 1
                              ? const SizedBox.shrink()
                              : link(i < activeIndex),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Scale down rather than wrap or clip on a narrow phone.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      steps[i]['label'] as String,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: i == activeIndex ? FontWeight.bold : FontWeight.w500,
                        color: i <= activeIndex ? surface.ink : surface.inkFaint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
