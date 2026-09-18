import 'package:flutter/material.dart';

import '../../core/constants/palette.dart';
import '../../core/constants/typography.dart';

/// The shared component set.
///
/// Before this, every screen drew its own card: five border radii, four
/// padding values, three different ways of saying "this is a label". These are
/// the pieces each screen now composes from, so consistency is what happens by
/// default rather than something that has to be re-achieved per screen.
///
/// Every one of them resolves colour from `context.lamp`, so all of it themes.

/* -------------------------------------------------------------------------- */
/* Surface                                                                    */
/* -------------------------------------------------------------------------- */

/// The standard content surface.
class LampCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? background;
  final Color? border;
  final bool raised;

  const LampCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.background,
    this.border,
    this.raised = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    final radius = BorderRadius.circular(LaMPRadius.card);

    final content = Container(
      padding: padding ?? const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: background ?? c.surface,
        borderRadius: radius,
        border: Border.all(color: border ?? c.line),
        // Tinted to the ground rather than neutral black, so a card lifts off
        // the page instead of looking like it is sitting in a puddle.
        boxShadow: raised
            ? [BoxShadow(color: c.shadow, blurRadius: 24, offset: const Offset(0, 8))]
            : null,
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: content,
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Headings                                                                   */
/* -------------------------------------------------------------------------- */

/// A section title, with an optional action on the right.
class LampSectionHeader extends StatelessWidget {
  final String title;
  final String? caption;
  final Widget? trailing;

  const LampSectionHeader({
    super.key,
    required this.title,
    this.caption,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: LaMPType.head.copyWith(color: c.ink)),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(caption!, style: LaMPType.caption.copyWith(color: c.inkFaint)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: Gap.md), trailing!],
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Status                                                                     */
/* -------------------------------------------------------------------------- */

enum LampTone { neutral, verified, pending, dispute, chain, brand }

extension LampToneColors on LampTone {
  Color fg(BuildContext context) {
    final c = context.lamp;
    return switch (this) {
      LampTone.neutral => c.inkMuted,
      LampTone.verified => c.verified,
      LampTone.pending => c.pending,
      LampTone.dispute => c.dispute,
      LampTone.chain => c.chain,
      LampTone.brand => c.brand,
    };
  }

  Color bg(BuildContext context) {
    final c = context.lamp;
    return switch (this) {
      LampTone.neutral => c.surfaceAlt,
      LampTone.verified => c.verifiedSoft,
      LampTone.pending => c.pendingSoft,
      LampTone.dispute => c.disputeSoft,
      LampTone.chain => c.chainSoft,
      LampTone.brand => c.brandSoft,
    };
  }
}

/// A state badge. Colour alone never carries the meaning — the word does.
class LampChip extends StatelessWidget {
  final String label;
  final LampTone tone;
  final IconData? icon;

  const LampChip({
    super.key,
    required this.label,
    this.tone = LampTone.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final fg = tone.fg(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 4),
      decoration: BoxDecoration(
        color: tone.bg(context),
        borderRadius: BorderRadius.circular(LaMPRadius.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: Gap.xs),
          ],
          Text(
            label,
            style: LaMPType.micro.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Figures                                                                    */
/* -------------------------------------------------------------------------- */

/// Label above, figure below — never the other way round.
///
/// The figure is the thing a person came to read, so it carries the weight and
/// the label recedes. Set in mono, because a column of money that does not
/// align is a column nobody trusts.
class LampStat extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;
  final Color? valueColor;
  final CrossAxisAlignment align;

  const LampStat({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.valueColor,
    this.align = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: LaMPType.caption.copyWith(color: c.inkFaint),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: Gap.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: align == CrossAxisAlignment.end
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Text(
            value,
            style: LaMPType.figure.copyWith(color: valueColor ?? c.ink),
            maxLines: 1,
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(
            caption!,
            style: LaMPType.micro.copyWith(color: c.inkFaint),
            maxLines: 2,
          ),
        ],
      ],
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Rows                                                                       */
/* -------------------------------------------------------------------------- */

/// One tappable line in a list. Fixed 56dp minimum, well past the 48dp floor.
class LampRow extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const LampRow({
    super.key,
    this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LaMPRadius.control),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.md,
            vertical: Gap.md,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (iconColor ?? c.brand).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(LaMPRadius.control),
                  ),
                  child: Icon(icon, size: IconSize.md, color: iconColor ?? c.brand),
                ),
                const SizedBox(width: Gap.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: LaMPType.sub.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: LaMPType.caption.copyWith(color: c.inkFaint),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: Gap.md),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A label/value pair that will not collide.
///
/// The pattern this replaces — two Texts either side of a Spacer — overflowed
/// on a phone in four separate places, because a Spacer distributes free space
/// and does nothing at all when there is none.
class LampKeyValue extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool mono;

  const LampKeyValue({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: LaMPType.caption.copyWith(color: c.inkFaint),
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: (mono ? LaMPType.monoCaption : LaMPType.caption).copyWith(
                color: valueColor ?? c.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Empty state                                                                */
/* -------------------------------------------------------------------------- */

/// An empty screen is an instruction, not a shrug.
class LampEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const LampEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: IconSize.lg, color: c.inkFaint),
            ),
            const SizedBox(height: Gap.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: LaMPType.head.copyWith(color: c.ink),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: LaMPType.body.copyWith(color: c.inkFaint),
            ),
            if (action != null) ...[const SizedBox(height: Gap.xl), action!],
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Progress                                                                   */
/* -------------------------------------------------------------------------- */

/// A labelled progress bar — the shape the scan count and the delivery ratio
/// both want.
class LampProgress extends StatelessWidget {
  final double value;
  final Color? color;

  const LampProgress({super.key, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 6,
        backgroundColor: c.surfaceSunken,
        valueColor: AlwaysStoppedAnimation(color ?? c.verified),
      ),
    );
  }
}
