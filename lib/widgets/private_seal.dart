import 'package:flutter/material.dart';
import '../core/constants/palette.dart';
import '../core/constants/formatters.dart';
import '../core/constants/typography.dart';

class PrivateSeal extends StatelessWidget {
  final String cleartext;
  final String hash;
  final bool isVisible;
  final String memberName;

  const PrivateSeal({
    super.key,
    required this.cleartext,
    required this.hash,
    required this.isVisible,
    required this.memberName,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    if (isVisible) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: c.line,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                cleartext,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.ink,
                ),
              ),
            ),
            const SizedBox(width: Gap.sm),
            // Flexible, because the member name is data: 'Bangladesh Bank ·
            // DGDA' is twice the width of 'Meghna' and this badge had no way
            // to give any of it back.
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: c.verified.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(LaMPRadius.control),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_open, size: 12, color: c.verified),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'visible to $memberName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: c.verified,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: c.line,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 16, color: c.inkFaint),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SEALED PRIVATE DATA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: c.inkFaint,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  LaMPFormatters.shortHash(hash, head: 16, tail: 12),
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback,
                    color: c.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: c.pending.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'hash only',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: c.pending,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
