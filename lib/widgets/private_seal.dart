import 'package:flutter/material.dart';
import '../core/constants/colors.dart';
import '../core/constants/formatters.dart';

class PrivateSeal extends StatelessWidget {
  final String cleartext;
  final String hash;
  final bool isVisible;
  final String memberName;
  final bool isDark;

  const PrivateSeal({
    super.key,
    required this.cleartext,
    required this.hash,
    required this.isVisible,
    required this.memberName,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isVisible) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? LaMPColors.portalSurface2 : LaMPColors.fieldSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? LaMPColors.portalLine : LaMPColors.fieldLine,
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
                  color: isDark ? LaMPColors.portalInk : LaMPColors.fieldInk,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: LaMPColors.verified.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_open, size: 12, color: LaMPColors.verifiedDark),
                  const SizedBox(width: 4),
                  Text(
                    'visible to $memberName',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: LaMPColors.verifiedDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? LaMPColors.portalLine : Colors.black12,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 16, color: LaMPColors.hashInk),
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
                    color: isDark ? LaMPColors.portalInk3 : LaMPColors.fieldInk3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  LaMPFormatters.shortHash(hash, head: 16, tail: 12),
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: LaMPColors.hashInk,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: LaMPColors.pending.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'hash only',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: LaMPColors.pending,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
