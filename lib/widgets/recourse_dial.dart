import 'package:flutter/material.dart';
import '../core/constants/colors.dart';
import '../core/models/domain_models.dart';
import '../core/constants/typography.dart';

class RecourseDial extends StatelessWidget {
  final List<RateCurveBand> bands;
  final RecourseTier currentTier;
  final bool isDark;

  const RecourseDial({
    super.key,
    required this.bands,
    required this.currentTier,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    const tiers = RecourseTier.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final tier in tiers) ...[
              Expanded(
                child: _buildTierCard(tier),
              ),
              if (tier != tiers.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildTierCard(RecourseTier tier) {
    final band = bands.firstWhere(
      (b) => b.tier == tier,
      orElse: () => RateCurveBand(
        tier: tier,
        advanceRatePct: tier == RecourseTier.newTier
            ? 70
            : (tier == RecourseTier.building
                ? 80
                : (tier == RecourseTier.established ? 85 : 90)),
        feePct: tier == RecourseTier.newTier
            ? 10.5
            : (tier == RecourseTier.building
                ? 8.8
                : (tier == RecourseTier.established ? 7.5 : 6.2)),
        manufacturerRecoursePct: tier == RecourseTier.newTier
            ? 60
            : (tier == RecourseTier.building
                ? 30
                : (tier == RecourseTier.established ? 15 : 0)),
        maxInvoiceValue: 1000000,
      ),
    );

    final isActive = tier == currentTier;
    final isReached = tier.index <= currentTier.index;

    final borderColor = isActive
        ? LaMPColors.brand
        : (isReached ? (isDark ? LaMPColors.portalLine2 : LaMPColors.fieldLine2) : Colors.transparent);

    final bgColor = isActive
        ? (isDark ? LaMPColors.brand.withValues(alpha: 0.25) : LaMPColors.brandSoft)
        : (isReached
            ? (isDark ? LaMPColors.portalSurface2 : LaMPColors.fieldSurface2)
            : (isDark ? LaMPColors.portalSurface : Colors.black.withValues(alpha: 0.03)));

    final textColor = isDark ? LaMPColors.portalInk : LaMPColors.fieldInk;
    final subColor = isDark ? LaMPColors.portalInk3 : LaMPColors.fieldInk3;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: isActive ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // black26 disappeared against the bank portal's dark card,
                  // so an unreached tier read as no dot at all.
                  color: isActive
                      ? LaMPColors.brand
                      : (isReached
                          ? LaMPColors.verified
                          : (isDark ? LaMPColors.portalSurface3 : Colors.black26)),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  tier.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: isActive ? LaMPColors.brand : subColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${band.advanceRatePct.round()}%',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback,
              color: textColor,
            ),
          ),
          Text(
            'advance',
            style: TextStyle(fontSize: 10, color: subColor),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 4,
              child: Row(
                children: [
                  Expanded(
                    flex: band.manufacturerRecoursePct.round(),
                    child: Container(color: LaMPColors.pending),
                  ),
                  Expanded(
                    flex: (100 - band.manufacturerRecoursePct).round(),
                    child: Container(color: LaMPColors.verified),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          // One figure, not two. Four tier cards across a phone leaves each
          // about ninety pixels, and "mfr 100" beside "bnk 0" overflowed every
          // one of them. The bank's share is the remainder, and the split bar
          // directly above already shows it.
          Text(
            'mfr ${band.manufacturerRecoursePct.round()}%',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontFamily: LaMPType.mono,
              fontFamilyFallback: LaMPType.fallback,
              color: subColor,
            ),
          ),
        ],
      ),
    );
  }
}
