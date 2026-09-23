import 'package:flutter/material.dart';
import '../core/constants/palette.dart';
import '../core/models/domain_models.dart';
import '../core/constants/typography.dart';

class RecourseDial extends StatelessWidget {
  final List<RateCurveBand> bands;
  final RecourseTier currentTier;

  const RecourseDial({
    super.key,
    required this.bands,
    required this.currentTier,
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
                child: _buildTierCard(context, tier),
              ),
              if (tier != tiers.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildTierCard(BuildContext context, RecourseTier tier) {
    final c = context.lamp;
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
        ? c.brand
        : (isReached ? c.lineStrong : Colors.transparent);

    final bgColor = isActive
        ? c.brandSoft
        : (isReached
            ? c.surfaceAlt
            : c.surfaceAlt);

    final textColor = c.ink;
    final subColor = c.inkFaint;

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
                      ? c.brand
                      : (isReached
                          ? c.verified
                          : c.surfaceSunken),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  tier.label.toUpperCase(),
                  style: LaMPType.label.copyWith(color: isActive ? c.brand : subColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${band.advanceRatePct.round()}%',
            style: LaMPType.figure.copyWith(color: textColor),
          ),
          Text(
            'advance',
            style: LaMPType.caption.copyWith(color: subColor),
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
                    child: Container(color: c.pending),
                  ),
                  Expanded(
                    flex: (100 - band.manufacturerRecoursePct).round(),
                    child: Container(color: c.verified),
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
            'Recourse ${band.manufacturerRecoursePct.round()}%',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LaMPType.monoCaption.copyWith(color: subColor),
          ),
        ],
      ),
    );
  }
}
