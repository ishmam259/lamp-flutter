import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/formatters.dart';
import '../../core/constants/palette.dart';
import '../../core/constants/typography.dart';
import '../../core/models/domain_models.dart';
import '../../core/state/lamp_state.dart';
import '../../core/world/seed.dart';
import '../../widgets/credit_ring.dart';
import '../../widgets/demo_director_sheet.dart';
import '../../widgets/ledger_inspector_sheet.dart';
import '../../widgets/lamp_mark.dart';
import '../../widgets/theme_toggle.dart';
import '../../widgets/ui/lamp_ui.dart';

/// The pharmacist's seat: what is owed, what it is building, and how to pay.
///
/// Rebuilt after the layout sweep found twenty overflows on this screen alone —
/// more than the other four put together. Nearly all of them were the same
/// mistake: a label and a value placed either side of a `spaceBetween`, which
/// fits until the value gets long and then silently runs off the card. Those
/// pairs are `LampKeyValue` now, which flexes both halves.
///
/// Navigation moved to the bottom. This is a phone held one-handed behind a
/// counter, and four scrollable tabs pinned under the status bar are the
/// furthest possible place from a thumb.
class PharmacyScreen extends StatefulWidget {
  final VoidCallback onBackToLauncher;

  const PharmacyScreen({super.key, required this.onBackToLauncher});

  @override
  State<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends State<PharmacyScreen> {
  int _tab = 0;
  String _payMethod = 'bKash';
  bool _justUpgraded = false;

  static const _invoiceAmount = 182400.0;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: LaMPTheme.of(context, LampWorld.field),
      child: Builder(builder: _buildScaffold),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final state = context.watch<LaMPState>();
    final c = context.lamp;
    final pharmacy = SeedData.pharmacies[0];
    final credit = state.creditHistory;

    if (credit == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBackToLauncher,
          tooltip: 'All seats',
        ),
        title: Row(
          children: [
            const LampMark(size: 22),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pharmacy.name,
                    style: LaMPType.head.copyWith(color: c.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    pharmacy.territory,
                    style: LaMPType.caption.copyWith(color: c.inkFaint),
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
        child: IndexedStack(
          index: _tab,
          children: [
            _dashboard(context, state, credit),
            _creditHistory(context, credit),
            _pay(context, state),
            _disputes(context, state),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.donut_large_outlined),
            selectedIcon: Icon(Icons.donut_large),
            label: 'Credit',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Pay',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag),
            label: 'Disputes',
          ),
        ],
      ),
    );
  }

  /* ---------------------------------------------------------------------- */
  /* Overview                                                                */
  /* ---------------------------------------------------------------------- */

  Widget _dashboard(BuildContext context, LaMPState state, CreditHistory credit) {
    final c = context.lamp;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
      children: [
        if (_justUpgraded) ...[
          LampCard(
            background: c.verifiedSoft,
            border: c.verified,
            child: Row(
              children: [
                Icon(Icons.trending_up, size: IconSize.lg, color: c.verified),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tier upgraded',
                        style: LaMPType.sub.copyWith(
                          color: c.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Now Established · 85% advance',
                        style: LaMPType.caption.copyWith(color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.lg),
        ],

        // The ring sits above the figures rather than beside them. At 110px
        // next to a column of text it left under 200px for the text and
        // overflowed; stacked, both get the full width.
        LampCard(
          child: Column(
            children: [
              CreditRing(
                cycles: credit.cycles,
                tier: credit.tier,
                size: 120,
                strokeWidth: 10,
              ),
              const SizedBox(height: Gap.lg),
              Text(
                credit.tier.label,
                style: LaMPType.title.copyWith(color: c.brand),
              ),
              const SizedBox(height: Gap.xs),
              Text(
                '${credit.cycles.length} cycles settled',
                style: LaMPType.caption.copyWith(color: c.inkFaint),
              ),
              const SizedBox(height: Gap.lg),
              Row(
                children: [
                  Expanded(
                    child: LampStat(
                      label: 'On time',
                      value: '${credit.onTimeCount}',
                      valueColor: c.verified,
                    ),
                  ),
                  Expanded(
                    child: LampStat(
                      label: 'Late',
                      value: '${credit.lateCount}',
                      valueColor: credit.lateCount > 0 ? c.pending : c.ink,
                    ),
                  ),
                  Expanded(
                    child: LampStat(
                      label: 'Defaults',
                      value: '${credit.defaultCount}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => setState(() => _tab = 1),
                  child: const Text('See cycle history'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.xl),

        const LampSectionHeader(title: 'Due now'),
        LampCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      state.demoInvoiceId,
                      style: LaMPType.monoBody.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const LampChip(label: 'Due in 45 days', tone: LampTone.pending),
                ],
              ),
              const SizedBox(height: Gap.md),
              LampKeyValue(
                label: 'Amount',
                value: LaMPFormatters.formatBDT(_invoiceAmount),
                valueColor: c.brand,
                mono: true,
              ),
              LampKeyValue(
                label: 'Supplier',
                value: 'Shomota Pharmaceuticals',
              ),
              const SizedBox(height: Gap.md),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() => _tab = 2),
                  child: const Text('Pay now'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /* ---------------------------------------------------------------------- */
  /* Credit                                                                  */
  /* ---------------------------------------------------------------------- */

  Widget _creditHistory(BuildContext context, CreditHistory credit) {
    final c = context.lamp;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
      children: [
        LampCard(
          child: Column(
            children: [
              CreditRing(
                cycles: credit.cycles,
                tier: credit.tier,
                size: 150,
                strokeWidth: 12,
              ),
              const SizedBox(height: Gap.lg),
              Text(
                credit.tier.label,
                style: LaMPType.title.copyWith(color: c.brand),
              ),
              const SizedBox(height: Gap.xs),
              Text(
                credit.tier.blurb,
                textAlign: TextAlign.center,
                style: LaMPType.caption.copyWith(color: c.inkFaint),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.xl),

        const LampSectionHeader(title: 'Settled cycles'),
        for (final cycle in credit.cycles.reversed) ...[
          LampCard(
            padding: const EdgeInsets.all(Gap.md),
            child: Row(
              children: [
                Icon(
                  cycle.onTime ? Icons.check_circle : Icons.schedule,
                  size: IconSize.md,
                  color: cycle.onTime ? c.verified : c.pending,
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cycle.invoiceId,
                        style: LaMPType.monoCaption.copyWith(
                          color: c.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        cycle.onTime
                            ? 'On time'
                            : '${cycle.daysLate} days late',
                        style: LaMPType.micro.copyWith(
                          color: cycle.onTime ? c.inkFaint : c.pending,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Text(
                  LaMPFormatters.formatBDTCompact(cycle.value),
                  style: LaMPType.monoCaption.copyWith(color: c.ink),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.sm),
        ],
      ],
    );
  }

  /* ---------------------------------------------------------------------- */
  /* Pay                                                                     */
  /* ---------------------------------------------------------------------- */

  Widget _pay(BuildContext context, LaMPState state) {
    final c = context.lamp;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
      children: [
        LampCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settle', style: LaMPType.head.copyWith(color: c.ink)),
              const SizedBox(height: Gap.md),
              LampKeyValue(
                label: 'Invoice',
                value: state.demoInvoiceId,
                mono: true,
              ),
              LampKeyValue(
                label: 'Amount',
                value: LaMPFormatters.formatBDT(_invoiceAmount),
                valueColor: c.brand,
                mono: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.xl),

        const LampSectionHeader(title: 'Pay with'),
        _payOption('bKash', 'Instant', LaMPColors.bKash),
        const SizedBox(height: Gap.sm),
        _payOption('Nagad', 'Instant', LaMPColors.nagad),
        const SizedBox(height: Gap.sm),
        _payOption('Bank transfer', 'Next business day', c.brand),

        const SizedBox(height: Gap.xl),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _executePayment(state, _invoiceAmount),
            // The button said "Confirm & Pay ৳1,82,400 via bKash" — seventy-
            // seven characters wrapping onto two lines. The amount and the
            // method are both on the card directly above it.
            child: Text('Pay ${LaMPFormatters.formatBDT(_invoiceAmount)}'),
          ),
        ),
      ],
    );
  }

  Widget _payOption(String name, String speed, Color accent) {
    final c = context.lamp;
    final selected = _payMethod == name;

    return LampCard(
      onTap: () => setState(() => _payMethod = name),
      padding: const EdgeInsets.all(Gap.md),
      background: selected ? accent.withValues(alpha: 0.08) : c.surface,
      border: selected ? accent : c.line,
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? accent : c.lineStrong,
                width: 2,
              ),
              color: selected ? accent : Colors.transparent,
            ),
            child: selected
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              name,
              style: LaMPType.sub.copyWith(
                color: selected ? accent : c.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(speed, style: LaMPType.caption.copyWith(color: c.inkFaint)),
        ],
      ),
    );
  }

  Future<void> _executePayment(LaMPState state, double amount) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: Gap.lg),
            Expanded(child: Text('Submitting to the ledger')),
          ],
        ),
      ),
    );

    final res = await state.settleReceivable(state.demoTokenId, amount, _payMethod);

    if (!mounted) return;
    Navigator.of(context).pop();

    setState(() => _justUpgraded = res.ok);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.ok ? 'Settled. Cycle recorded.' : (res.error ?? 'Refused')),
      ),
    );

    if (res.ok) setState(() => _tab = 0);
  }

  /* ---------------------------------------------------------------------- */
  /* Disputes                                                                */
  /* ---------------------------------------------------------------------- */

  Widget _disputes(BuildContext context, LaMPState state) {
    final c = context.lamp;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
      children: [
        LampCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Raise a dispute', style: LaMPType.head.copyWith(color: c.ink)),
              const SizedBox(height: Gap.xs),
              Text(
                'Before the 24-hour window closes',
                style: LaMPType.caption.copyWith(color: c.inkFaint),
              ),
              const SizedBox(height: Gap.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.dispute,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await state.raiseDispute(
                      state.demoTokenId,
                      'Damaged seals reported by Rahman Medical Hall',
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Dispute raised')),
                    );
                  },
                  icon: const Icon(Icons.report_problem_outlined, size: IconSize.sm),
                  label: const Text('Report a problem'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
