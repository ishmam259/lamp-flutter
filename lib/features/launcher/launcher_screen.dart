import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/palette.dart';
import '../../core/constants/typography.dart';
import '../../core/constants/formatters.dart';
import '../../core/world/queries.dart';
import '../../core/state/lamp_state.dart';
import '../../widgets/demo_director_sheet.dart';
import '../../widgets/ledger_inspector_sheet.dart';
import '../../widgets/lamp_mark.dart';
import '../../widgets/theme_toggle.dart';
import '../../widgets/ui/lamp_ui.dart';

/// Pick a seat.
///
/// This screen used to open with a headline and a line of positioning copy —
/// "Five interfaces over one consortium ledger", "Make the invoice itself
/// trustworthy, so the money can follow the medicine" — and then describe each
/// seat in a sentence of about eighty characters. That is a pitch deck. Someone
/// opening the app already knows what it is; what they need is the state of the
/// ledger and a way in. The pitch is gone and the descriptions with it: a seat
/// is named by its role and its organisation, which is what a person actually
/// scans for.
class LauncherScreen extends StatelessWidget {
  final ValueChanged<PersonaId> onSelectPersona;

  const LauncherScreen({super.key, required this.onSelectPersona});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LaMPState>();
    final c = context.lamp;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: Gap.lg,
        title: Row(
          children: [
            const LampMark(size: 28),
            const SizedBox(width: Gap.sm),
            // Flexible, because three action buttons plus the leading mark
            // leave under 160dp for the title on a 360dp phone.
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'LaMP',
                    style: LaMPType.head.copyWith(color: c.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Last Mile Pharmacy',
                    style: LaMPType.monoCaption.copyWith(color: c.inkFaint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          const ThemeToggle(),
          IconButton(
            tooltip: 'Ledger',
            icon: Icon(Icons.account_tree_outlined, color: c.inkMuted),
            onPressed: () => LedgerInspectorSheet.show(context),
          ),
          IconButton(
            tooltip: 'Demo controls',
            icon: Icon(Icons.tune, color: c.inkMuted),
            onPressed: () => DemoDirectorSheet.show(context),
          ),
          const SizedBox(width: Gap.xs),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
          children: [
            _LedgerStrip(state: state),
            const SizedBox(height: Gap.xl),

            const LampSectionHeader(
              title: 'In the field',
              caption: 'Phone apps, built for sunlight',
            ),
            _SeatCard(
              icon: Icons.qr_code_scanner,
              title: 'Delivery officer',
              org: 'Kamrul Hasan · Bogura Sadar',
              tone: LampTone.brand,
              onTap: () => onSelectPersona(PersonaId.mpo),
            ),
            const SizedBox(height: Gap.md),
            _SeatCard(
              icon: Icons.local_pharmacy_outlined,
              title: 'Pharmacy',
              org: 'Rahman Medical Hall · রহমান মেডিকেল হল',
              tone: LampTone.verified,
              onTap: () => onSelectPersona(PersonaId.pharmacy),
            ),

            const SizedBox(height: Gap.xl),
            const LampSectionHeader(
              title: 'At the desk',
              caption: 'Institutional portals on one channel',
            ),
            _SeatCard(
              icon: Icons.business_outlined,
              title: 'Manufacturer',
              org: 'Shomota Pharmaceuticals',
              tone: LampTone.brand,
              onTap: () => onSelectPersona(PersonaId.manufacturer),
            ),
            const SizedBox(height: Gap.md),
            _SeatCard(
              icon: Icons.account_balance_outlined,
              title: 'Bank',
              org: 'Meghna Commercial · Padma',
              tone: LampTone.pending,
              onTap: () => onSelectPersona(PersonaId.bank),
            ),
            const SizedBox(height: Gap.md),
            _SeatCard(
              icon: Icons.verified_user_outlined,
              title: 'Regulator',
              org: 'Bangladesh Bank · DGDA',
              tone: LampTone.chain,
              onTap: () => onSelectPersona(PersonaId.regulator),
            ),
          ],
        ),
      ),
    );
  }
}

/// The ledger, in three figures.
///
/// What replaced the headline. A person opening the app wants to know the chain
/// is alive and which invoice the demo is on; both fit here, and neither needs
/// a sentence.
class _LedgerStrip extends StatelessWidget {
  final LaMPState state;

  const _LedgerStrip({required this.state});

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;

    return LampCard(
      raised: true,
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: c.verified,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  'Consortium ledger · lamp-channel',
                  style: LaMPType.monoCaption.copyWith(color: c.inkFaint),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Short labels and a wider share for the invoice id, which is
              // the longest value of the three. "Open invoices" did not fit its
              // column and ran into the label beside it.
              Expanded(
                flex: 2,
                child: LampStat(
                  label: 'Block',
                  value: '${state.blockHeight}',
                  valueColor: c.verified,
                ),
              ),
              Expanded(
                flex: 2,
                // Was the literal '1'. Minting a second invoice left the
                // launcher still claiming there was one.
                child: LampStat(
                  label: 'Receivables',
                  value: '${state.tokenViews.length}',
                ),
              ),
              Expanded(
                flex: 4,
                child: LampStat(
                  label: 'Outstanding',
                  value: LaMPFormatters.formatBDTCompact(
                    state.tokenViews
                        .where((v) => v.token.isOpen)
                        .fold<double>(0.0, (sum, v) => sum + v.token.declaredValue),
                  ),
                  valueColor: c.brand,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One seat. Role, organisation, and a way in — nothing else.
class _SeatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String org;
  final LampTone tone;
  final VoidCallback onTap;

  const _SeatCard({
    required this.icon,
    required this.title,
    required this.org,
    required this.tone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    final accent = tone.fg(context);

    return LampCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Gap.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tone.bg(context),
              borderRadius: BorderRadius.circular(LaMPRadius.card),
            ),
            child: Icon(icon, size: IconSize.lg, color: accent),
          ),
          const SizedBox(width: Gap.md),
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
                const SizedBox(height: 2),
                Text(
                  org,
                  style: LaMPType.caption.copyWith(color: c.inkFaint),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          Icon(Icons.chevron_right, size: IconSize.md, color: c.inkFaint),
        ],
      ),
    );
  }
}
