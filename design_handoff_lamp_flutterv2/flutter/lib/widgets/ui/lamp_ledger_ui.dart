import 'package:flutter/material.dart';

import '../../core/constants/palette.dart';
import '../../core/constants/typography.dart';
import '../lamp_mark.dart';

/// The ledger-specific building blocks from the redesign. Every new screen
/// composes these plus `lamp_ui.dart` (LampCard, LampRow, LampChip, LampStat,
/// LampSectionHeader, LampKeyValue, LampEmpty) — it never hand-builds them.

/// The three states. There is no fourth. Provenance is not a colour.
enum LampState { confirmed, pending, refused }

extension LampStateColor on LampState {
  Color color(BuildContext context) {
    final c = context.lamp;
    return switch (this) {
      LampState.confirmed => c.verified,
      LampState.pending => c.pending,
      LampState.refused => c.dispute,
    };
  }
}

/// 6dp state dot with optional label. The ONLY way state colour appears on a
/// row — never as a fill behind the row.
class LampStateDot extends StatelessWidget {
  final LampState state;
  final String? label;
  const LampStateDot(this.state, {super.key, this.label});

  @override
  Widget build(BuildContext context) {
    final col = state.color(context);
    final dot = Container(
      width: 6, height: 6,
      decoration: BoxDecoration(color: col, shape: BoxShape.circle),
    );
    if (label == null) return dot;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      dot,
      const SizedBox(width: Gap.sm),
      Text(label!, style: LaMPType.meta.copyWith(color: col)),
    ]);
  }
}

/// Mono footer under a hairline. Anything written to the ledger ends in one;
/// off-chain rows never do.
class LampReceiptFooter extends StatelessWidget {
  final int block;
  final String tx;
  const LampReceiptFooter({super.key, required this.block, required this.tx});

  String get _shortTx =>
      tx.length <= 12 ? tx : '${tx.substring(0, 6)}…${tx.substring(tx.length - 4)}';

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Divider(height: Gap.xl, thickness: 1, color: c.line),
      Text('BLK $block · tx $_shortTx',
          style: LaMPType.monoMicro.copyWith(color: c.inkFaint)),
    ]);
  }
}

/// A card for a ledger write: content, then the receipt footer.
class LampReceiptCard extends StatelessWidget {
  final Widget child;
  final int block;
  final String tx;
  final VoidCallback? onTap;
  const LampReceiptCard(
      {super.key, required this.child, required this.block, required this.tx, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaMPRadius.card),
        side: BorderSide(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gap.card),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            child,
            LampReceiptFooter(block: block, tx: tx),
          ]),
        ),
      ),
    );
  }
}

/// Countable progress: one tick per item. Use instead of a percentage bar
/// whenever the total is a real count (cartons, cycles). `refused` indices
/// draw red in place so the misroute is visible in position.
class LampTickBar extends StatelessWidget {
  final int total;
  final int confirmed;
  final Set<int> refused;
  const LampTickBar(
      {super.key, required this.total, required this.confirmed, this.refused = const {}});

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    return Row(children: [
      for (var i = 0; i < total; i++) ...[
        if (i > 0) const SizedBox(width: 2),
        Expanded(
          child: Container(
            height: 16,
            decoration: BoxDecoration(
              color: refused.contains(i)
                  ? c.dispute
                  : i < confirmed
                      ? c.verified
                      : c.surfaceSunken,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    ]);
  }
}

/// App-bar title for every seat: mark + seat name + optional sans subtitle.
/// Put it in `LumaAppBar(title: …)` / `AppBar(title: …)`.
class LampSeatTitle extends StatelessWidget {
  final String seat;
  final String? subtitle;
  const LampSeatTitle(this.seat, {super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const LampMark(size: 38),
      const SizedBox(width: Gap.md),
      Flexible(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(seat, style: LaMPType.head.copyWith(color: c.ink),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (subtitle != null)
              Text(subtitle!, style: LaMPType.caption.copyWith(color: c.inkMuted),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    ]);
  }
}

/// Live block pip for the app-bar `actions`. Opens the ledger inspector.
/// This is the only app-bar action a seat gets besides the theme toggle.
class LampBlockPip extends StatelessWidget {
  final int block;
  final VoidCallback onTap;
  const LampBlockPip({super.key, required this.block, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    return Padding(
      padding: const EdgeInsets.only(right: Gap.lg),
      child: Material(
        color: c.surfaceAlt,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.md),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const LampStateDot(LampState.confirmed),
                const SizedBox(width: Gap.sm),
                Text('BLK $block', style: LaMPType.monoCaption.copyWith(color: c.inkMuted)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Uppercase mono eyebrow above a group. Pass text in any case.
class LampEyebrow extends StatelessWidget {
  final String text;
  const LampEyebrow(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: LaMPType.label.copyWith(color: context.lamp.inkFaint));
}
