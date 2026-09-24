import 'package:flutter/material.dart';

import '../../core/constants/palette.dart';
import '../../core/constants/typography.dart';
import '../../core/design/luma_elevation.dart';
import '../../core/design/luma_press.dart';

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
///
/// Two things changed here on this branch, and both are Luma's.
///
/// The press is a transform now, not a ripple. A ripple on a card 340dp wide
/// takes most of a second to cross it, so the acknowledgement lands well after
/// the finger has already lifted; a 2.5% squeeze lands on contact. See
/// [LumaPress] for the rest of that argument.
///
/// The shadow is layered rather than single — see [LumaElevation]. A card at
/// rest now casts something, which is what separates it from the page when the
/// hairline border is the same value as the background in dark mode.
class LampCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? background;
  final Color? border;

  /// The card that is the point of the screen. One per view, or the word
  /// stops meaning anything.
  final bool raised;

  /// Drops the shadow entirely, for a card nested inside another card where a
  /// cast would read as a rendering mistake.
  final bool flat;

  const LampCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.background,
    this.border,
    this.raised = false,
    this.flat = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    final radius = BorderRadius.circular(LaMPRadius.card);

    final content = Container(
      padding: padding ?? const EdgeInsets.all(Gap.card),
      decoration: BoxDecoration(
        color: background ?? c.surface,
        borderRadius: radius,
        border: Border.all(color: border ?? c.line),
        boxShadow: flat
            ? LumaElevation.none
            : raised
                ? LumaElevation.raised(context)
                : LumaElevation.rest(context),
      ),
      child: child,
    );

    if (onTap == null) return content;

    return LumaPress(
      onTap: onTap,
      borderRadius: radius,
      child: content,
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
      padding: const EdgeInsets.only(bottom: Gap.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: LaMPType.head.copyWith(color: c.ink)),
                if (caption != null) ...[
                  const SizedBox(height: Gap.xs),
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

enum LampTone { neutral, verified, pending, dispute, brand }

extension LampToneColors on LampTone {
  Color fg(BuildContext context) {
    final c = context.lamp;
    return switch (this) {
      LampTone.neutral => c.inkMuted,
      LampTone.verified => c.verified,
      LampTone.pending => c.pending,
      LampTone.dispute => c.dispute,
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
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 5),
      decoration: BoxDecoration(
        // Pill, not a rounded rectangle. A badge that shares its corner radius
        // with the buttons around it invites a tap it will not answer; the
        // shape is doing the affordance work here.
        color: tone.bg(context),
        borderRadius: BorderRadius.circular(LaMPRadius.pill),
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
            style: LaMPType.caption.copyWith(color: fg, fontWeight: FontWeight.w600),
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
        const SizedBox(height: Gap.sm),
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
            style: LaMPType.caption.copyWith(color: c.inkFaint),
            maxLines: 2,
          ),
        ],
      ],
    );
  }
}

/// Two or three figures across the width of a card.
///
/// This exists because of a defect that only appeared on a real phone, and
/// that no test in this repo could have caught.
///
/// Three `LampStat`s in `Expanded`s is the obvious way to write the row, and
/// it is what the route card, the launcher strip and the pharmacy dashboard
/// all did. It never overflows — `LampStat` scales its figure down rather
/// than pushing its neighbours off — and that is exactly the problem. A
/// figure long enough to need scaling is scaled to fill its column *exactly*,
/// and the next column begins at that same pixel. On the delivery officer's
/// route card, `INV-00235` and `0/25` came out as `INV-002350/25`: no
/// overflow, no exception, nothing for the layout sweep to report, and
/// completely unreadable.
///
/// A gutter is the whole fix. It is a component rather than a `SizedBox` at
/// three call sites so that the next stat row gets it without anyone
/// remembering.
class LampStatRow extends StatelessWidget {
  final List<Widget> children;

  /// Column weights, when the figures are not the same length — the launcher
  /// gives the invoice id twice the share of the block height. Must match
  /// [children] in length; equal columns when omitted.
  final List<int>? flex;

  /// The gap between columns. `Gap.lg`, not `Gap.sm`: this is separating two
  /// figures set in the same weight at the same size, and at 8dp the eye
  /// still groups them into one number.
  final double gutter;

  const LampStatRow({
    super.key,
    required this.children,
    this.flex,
    this.gutter = Gap.lg,
  }) : assert(
          flex == null || flex.length == children.length,
          'flex must give a weight for every column',
        );

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: gutter),
          Expanded(flex: flex?[i] ?? 1, child: children[i]),
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
          // 64, not 56. The floor for a touch target is 48 and this has never
          // been near it; the number that matters here is the one that keeps
          // two lines of 16/13 text off each other's leading.
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.lg,
            vertical: Gap.md,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (iconColor ?? c.brand).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(LaMPRadius.control),
                  ),
                  child: Icon(icon, size: IconSize.md, color: iconColor ?? c.brand),
                ),
                const SizedBox(width: Gap.lg),
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
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
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
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: IconSize.xl, color: c.inkFaint),
            ),
            const SizedBox(height: Gap.xl),
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
      borderRadius: BorderRadius.circular(LaMPRadius.pill),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 8,
        backgroundColor: c.surfaceSunken,
        valueColor: AlwaysStoppedAnimation(color ?? c.verified),
      ),
    );
  }
}
