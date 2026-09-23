import 'package:flutter/material.dart';
import '../core/constants/palette.dart';
import '../core/constants/typography.dart';
import '../core/models/domain_models.dart';

/// Where an invoice is in its life: issued, delivered, financed, paid.
///
/// Four equal columns with the label under each step, so all four fit a
/// 360dp card. It used to lay the steps out in one scrolling row with the
/// labels beside them, which cut "Financed" to "Fi" at the card's edge.
class LifecycleRail extends StatelessWidget {
  final TokenState state;
  final bool isFinanced;

  const LifecycleRail({
    super.key,
    required this.state,
    this.isFinanced = false,
  });

  static const _labels = ['Issued', 'Delivered', 'Financed', 'Paid'];

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;

    int reached = 0;
    if (state == TokenState.settled) {
      reached = 3;
    } else if (state == TokenState.financed || isFinanced) {
      reached = 2;
    } else if (state == TokenState.delivered) {
      reached = 1;
    }
    final disputed = state == TokenState.disputed;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _labels.length; i++)
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: 24,
                  child: Row(
                    children: [
                      Expanded(
                        child: i == 0
                            ? const SizedBox()
                            : Container(
                                height: 2,
                                color: i <= reached ? c.verified : c.line,
                              ),
                      ),
                      _dot(context, i, reached, disputed),
                      Expanded(
                        child: i == _labels.length - 1
                            ? const SizedBox()
                            : Container(
                                height: 2,
                                color: i < reached ? c.verified : c.line,
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  _labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LaMPType.caption.copyWith(
                    color: i <= reached ? c.ink : c.inkFaint,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dot(BuildContext context, int i, int reached, bool disputed) {
    final c = context.lamp;
    final done = i <= reached;
    // The step after the last one reached is what is being waited on; a
    // dispute stops the rail there, in refused red.
    final next = i == reached + 1;
    final Color ring = done
        ? c.verified
        : next
            ? (disputed ? c.dispute : c.pending)
            : c.lineStrong;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? c.verified : Colors.transparent,
        border: Border.all(color: ring, width: 2),
      ),
      child: done ? Icon(Icons.check, size: 14, color: c.bg) : null,
    );
  }
}
