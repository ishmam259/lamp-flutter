import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../core/auth/accounts.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/constants/app_mode.dart';
import '../../core/constants/formatters.dart';
import '../../core/constants/ledger_labels.dart';
import '../../core/constants/palette.dart';
import '../../core/models/ledger_models.dart';
import '../../core/constants/typography.dart';
import '../../core/state/theme_controller.dart';
import '../demo_director_sheet.dart';

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

/// The footer under a hairline that marks a card as something the ledger
/// recorded: what happened and when, in plain words, and a way into the
/// details. Off-chain rows never have one.
///
/// It used to print `BLK 27 · tx-0ce30…9d8619 · recordPoD ›` — the system's
/// vocabulary, not the reader's. The block and transaction id are still one
/// tap away, in the ledger view.
class LampReceiptFooter extends StatelessWidget {
  final ChainTx tx;
  final VoidCallback? onOpen;
  const LampReceiptFooter({super.key, required this.tx, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Divider(height: Gap.xl, thickness: 1, color: c.line),
      Row(children: [
        Icon(Icons.verified_outlined, size: IconSize.sm, color: c.inkFaint),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: Text(
            '${LedgerLabels.event(tx.fn)} · '
            '${LaMPFormatters.formatDateShort(tx.timestamp)}, '
            '${LaMPFormatters.formatClock(tx.timestamp)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LaMPType.caption.copyWith(color: c.inkFaint),
          ),
        ),
        if (onOpen != null)
          InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(LaMPRadius.control),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.xs),
              child: Text('Details ›',
                  style: LaMPType.meta.copyWith(color: c.inkMuted)),
            ),
          ),
      ]),
    ]);
  }
}

/// A card for a ledger write: content, then the receipt footer.
class LampReceiptCard extends StatelessWidget {
  final Widget child;
  final ChainTx tx;
  final VoidCallback? onOpen;
  final VoidCallback? onTap;
  const LampReceiptCard(
      {super.key, required this.child, required this.tx, this.onOpen, this.onTap});

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
            LampReceiptFooter(tx: tx, onOpen: onOpen),
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
  final List<LampState?> ticks;

  /// The first [confirmed] ticks confirmed, [refused] indices red.
  LampTickBar(
      {super.key, required int total, required int confirmed, Set<int> refused = const {}})
      : ticks = [
          for (var i = 0; i < total; i++)
            refused.contains(i)
                ? LampState.refused
                : i < confirmed
                    ? LampState.confirmed
                    : null,
        ];

  /// One state per tick, in position; null is not yet done. Cartons are
  /// scanned out of order and a refusal sits where it happened, so a count
  /// alone cannot draw them.
  const LampTickBar.of(this.ticks, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    return Row(children: [
      for (var i = 0; i < ticks.length; i++) ...[
        if (i > 0) const SizedBox(width: 2),
        Expanded(
          child: Container(
            height: 16,
            decoration: BoxDecoration(
              color: ticks[i]?.color(context) ?? c.surfaceSunken,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    ]);
  }
}

/// A state as a pill: 6dp dot and an uppercase mono word on the state's soft
/// tint. The tint is allowed here and nowhere larger.
class LampStateChip extends StatelessWidget {
  final LampState state;
  final String label;
  const LampStateChip(this.state, this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    final bg = switch (state) {
      LampState.confirmed => c.verifiedSoft,
      LampState.pending => c.pendingSoft,
      LampState.refused => c.disputeSoft,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.xs),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(LaMPRadius.pill),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        LampStateDot(state),
        const SizedBox(width: Gap.sm),
        Text(label.toUpperCase(),
            style: LaMPType.label.copyWith(color: state.color(context))),
      ]),
    );
  }
}

/// The seat's overflow: who is signed in, theme, and sign out — each with a
/// label. Replaces the row of unlabelled icons that used to crowd the app bar.
/// Switching account and the demo controls are testing tools (`kDemoTools`).
class LampSeatMenu extends StatelessWidget {
  const LampSeatMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    final theme = context.watch<ThemeController>();
    final auth = Provider.of<AuthController?>(context);
    final account = auth?.current;

    PopupMenuItem<int> item(int value, IconData icon, String label) => PopupMenuItem(
          value: value,
          child: Row(children: [
            Icon(icon, size: IconSize.md, color: c.inkMuted),
            const SizedBox(width: Gap.md),
            Text(label, style: LaMPType.body.copyWith(color: c.ink)),
          ]),
        );

    return PopupMenuButton<int>(
      tooltip: 'More',
      icon: Icon(Icons.more_horiz, color: c.inkMuted),
      onSelected: (v) {
        switch (v) {
          case 0:
            theme.cycle();
          case 1:
            DemoDirectorSheet.show(context);
          case 2:
            _switchAccount(context, auth!);
          case 3:
            auth?.signOut();
        }
      },
      itemBuilder: (_) => [
        if (account != null)
          PopupMenuItem<int>(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.name, style: LaMPType.sub.copyWith(color: c.ink)),
                Text(account.org, style: LaMPType.caption.copyWith(color: c.inkFaint)),
              ],
            ),
          ),
        if (account != null) const PopupMenuDivider(),
        item(0, theme.icon, 'Theme · ${theme.label}'),
        if (kDemoTools) item(1, Icons.tune, 'Demo controls'),
        if (kDemoTools && auth != null) item(2, Icons.switch_account_outlined, 'Switch account'),
        if (auth != null) item(3, Icons.logout, 'Sign out'),
      ],
    );
  }

  /// Testing only: open any account's seat without its PIN.
  static void _switchAccount(BuildContext context, AuthController auth) {
    final c = context.lamp;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: Gap.md),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md),
              child: Text('Switch account', style: LaMPType.head.copyWith(color: c.ink)),
            ),
            for (final a in Accounts.all)
              ListTile(
                title: Text(a.name, style: LaMPType.sub.copyWith(color: c.ink)),
                subtitle: Text('${a.org} · ${a.role}',
                    style: LaMPType.caption.copyWith(color: c.inkFaint)),
                trailing: a.id == auth.current?.id
                    ? Icon(Icons.check, color: c.inkMuted, size: IconSize.md)
                    : null,
                onTap: () {
                  Navigator.pop(sheet);
                  auth.switchTo(a);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// The ledger pill for the app-bar `actions`: a live dot and the word
/// "Ledger". Opens the ledger view. This is the only app-bar action a seat
/// gets besides the overflow menu.
class LampBlockPip extends StatelessWidget {
  final VoidCallback onTap;
  const LampBlockPip({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
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
                Text('Ledger', style: LaMPType.meta.copyWith(color: c.inkMuted)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Uppercase mono eyebrow above a group. Pass text in any case. With
/// [trailing], a hairline runs from the label to a count on the right:
/// `NEXT ──── 2 stops`.
class LampEyebrow extends StatelessWidget {
  final String text;
  final String? trailing;
  const LampEyebrow(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    final label = Text(text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: LaMPType.label.copyWith(color: c.inkFaint));
    if (trailing == null) return label;
    // Each side keeps its natural width up to a cap and ellipsises past it;
    // the hairline takes whatever is left. Splitting the width by flex
    // squeezed a long label even beside a two-character count.
    return LayoutBuilder(builder: (context, box) {
      return Row(children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: box.maxWidth * 0.62),
          child: label,
        ),
        const SizedBox(width: Gap.md),
        Expanded(child: Divider(height: 1, thickness: 1, color: c.line)),
        const SizedBox(width: Gap.md),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: box.maxWidth * 0.3),
          child: Text(trailing!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LaMPType.monoCaption.copyWith(color: c.inkFaint)),
        ),
      ]);
    });
  }
}
