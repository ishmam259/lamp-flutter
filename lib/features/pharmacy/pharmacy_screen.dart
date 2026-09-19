import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/formatters.dart';
import '../../core/constants/palette.dart';
import '../../core/constants/typography.dart';
import '../../core/models/domain_models.dart';
import '../../core/state/lamp_state.dart';
import '../../core/world/queries.dart';
import '../../core/world/seed.dart';
import '../../widgets/credit_ring.dart';
import '../../widgets/demo_director_sheet.dart';
import '../../widgets/ledger_inspector_sheet.dart';
import '../../widgets/lamp_mark.dart';
import '../../widgets/theme_toggle.dart';
import '../../widgets/ui/lamp_skeleton.dart';
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

  /// Set after a settlement that moved the counterparty up a tier.
  ///
  /// Was a `bool` behind the literal line "Now Established · 85% advance",
  /// which is what the banner said whatever tier you were actually on — and
  /// it never cleared, so it stayed up for the rest of the session.
  String? _upgradeCaption;

  /// Which receivable the Pay tab is settling.
  ///
  /// Null means "whichever is due first". The screen used to settle
  /// `state.demoTokenId` no matter what was on screen.
  String? _payTokenId;

  /// The receivables this pharmacy still owes, nearest due date first.
  List<TokenView> _open(LaMPState state) =>
      state.openForPharmacy(SeedData.pharmacies[0].did);

  /// The one the Pay tab acts on: the chosen invoice if it is still payable,
  /// otherwise the first that is.
  TokenView? _payable(LaMPState state) {
    final open = _open(state);
    for (final v in open) {
      if (v.tokenId == _payTokenId && v.token.isPayable) return v;
    }
    for (final v in open) {
      if (v.token.isPayable) return v;
    }
    return null;
  }

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
    // Read the pharmacy's own key off the ledger rather than the single
    // cached history, which only ever held the demo counterparty's.
    final credit = state.creditFor(pharmacy.did) ?? state.creditHistory;

    if (credit == null) {
      // The world is still seeding. A skeleton in the shape of this screen
      // rather than a spinner in the middle of nothing.
      return const LampLoadingScreen();
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
    final open = _open(state);
    final owed = open.fold<double>(
      0.0,
      (sum, TokenView v) => sum + v.token.declaredValue,
    );
    final recent = state.forPharmacy(SeedData.pharmacies[0].did).take(5).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
      children: [
        if (_upgradeCaption != null) ...[
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
                        _upgradeCaption!,
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
        _dueNowCard(context, open.isEmpty ? null : open.first),

        if (open.isNotEmpty) ...[
          const SizedBox(height: Gap.md),
          LampKeyValue(
            label: 'Total outstanding',
            value: LaMPFormatters.formatBDT(owed),
            mono: true,
          ),
        ],

        const SizedBox(height: Gap.xl),
        const LampSectionHeader(title: 'Recent deliveries'),
        if (recent.isEmpty)
          Text(
            'Nothing delivered yet.',
            style: LaMPType.small.copyWith(color: c.inkFaint),
          )
        else
          for (final v in recent) ...[
            _recentRow(context, v),
            const SizedBox(height: Gap.sm),
          ],
      ],
    );
  }

  /// One past or in-flight consignment.
  ///
  /// This is where a settled invoice goes when it leaves "Due now" — without
  /// it, paying makes the invoice vanish with nothing to show it landed.
  Widget _recentRow(BuildContext context, TokenView v) {
    final c = context.lamp;
    final token = v.token;
    final tone = switch (token.state) {
      TokenState.settled => LampTone.verified,
      TokenState.disputed => LampTone.dispute,
      TokenState.financed => LampTone.chain,
      TokenState.delivered => LampTone.verified,
      _ => LampTone.neutral,
    };

    return LampCard(
      padding: const EdgeInsets.all(Gap.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        token.invoiceId,
                        style: LaMPType.monoCaption.copyWith(
                          color: c.ink,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    LampChip(label: token.state.label, tone: tone),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${LaMPFormatters.formatDate(token.issuedAt)} · '
                  '${token.declaredCartons} cartons',
                  style: LaMPType.micro.copyWith(color: c.inkFaint),
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          Text(
            LaMPFormatters.formatBDTCompact(token.declaredValue),
            style: LaMPType.monoCaption.copyWith(color: c.ink),
          ),
        ],
      ),
    );
  }

  /// "Due now" — the next receivable this pharmacy owes, or the empty state.
  ///
  /// Two rules, both the chaincode's rather than this screen's:
  ///
  ///   * a settled receivable is not owed, so it is not in [open] at all; and
  ///   * `settle` accepts DELIVERED or FINANCED and nothing else, so the
  ///     payment CTA only appears once the goods have actually been recorded
  ///     as delivered on the ledger.
  ///
  /// The screen used to show **Pay now** against a CREATED receivable — a bill
  /// for goods nobody had delivered — and to treat FINANCED as "nothing to
  /// pay", which it is not: the bank advances against the receivable to the
  /// manufacturer, and the pharmacy still owes the full amount.
  Widget _dueNowCard(BuildContext context, TokenView? next) {
    final c = context.lamp;

    if (next == null) {
      return LampCard(
        background: c.verifiedSoft,
        border: c.verified,
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, size: IconSize.lg, color: c.verified),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nothing outstanding',
                    style: LaMPType.sub.copyWith(
                      color: c.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Every invoice on this counter has settled',
                    style: LaMPType.caption.copyWith(color: c.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final state = context.read<LaMPState>();
    final token = next.token;
    final overdue = token.dueDate < state.now;

    return LampCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  token.invoiceId,
                  style: LaMPType.monoBody.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              LampChip(
                label: LaMPFormatters.formatDaysUntil(token.dueDate, state.now),
                tone: overdue ? LampTone.dispute : LampTone.pending,
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          LampKeyValue(
            label: 'Amount',
            value: LaMPFormatters.formatBDT(token.declaredValue),
            valueColor: c.brand,
            mono: true,
          ),
          LampKeyValue(
            label: 'Supplier',
            value: SeedData.manufacturer.name,
          ),
          const SizedBox(height: Gap.md),
          if (token.isPayable)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => setState(() {
                  _payTokenId = token.tokenId;
                  _tab = 2;
                }),
                child: const Text('Pay now'),
              ),
            )
          else
            Text(
              token.state == TokenState.disputed
                  ? 'Resolve the dispute before settling.'
                  : 'Payable once the delivery is confirmed on the ledger.',
              style: LaMPType.caption.copyWith(color: c.inkMuted),
            ),
        ],
      ),
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
    final target = _payable(state);
    final open = _open(state);

    if (target == null) {
      // Nothing the chaincode would accept. Say which of the two reasons it
      // is, rather than offering a button that will be refused.
      final waiting = open.isNotEmpty;
      return ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
        children: [
          LampCard(
            background: waiting ? c.pendingSoft : c.verifiedSoft,
            border: waiting ? c.pending : c.verified,
            child: Row(
              children: [
                Icon(
                  waiting ? Icons.schedule : Icons.check_circle_outline,
                  size: IconSize.lg,
                  color: waiting ? c.pending : c.verified,
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        waiting ? 'Not payable yet' : 'Nothing to settle',
                        style: LaMPType.sub.copyWith(
                          color: c.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        waiting
                            ? '${open.first.token.invoiceId} is '
                                '${open.first.token.state.label.toLowerCase()}. '
                                'Payable once the delivery is confirmed.'
                            : 'Every invoice on this counter has settled',
                        style: LaMPType.caption.copyWith(color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final token = target.token;

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
                value: token.invoiceId,
                mono: true,
              ),
              LampKeyValue(
                label: 'Amount',
                value: LaMPFormatters.formatBDT(token.declaredValue),
                valueColor: c.brand,
                mono: true,
              ),
              LampKeyValue(
                label: 'Due',
                value: LaMPFormatters.formatDate(token.dueDate),
              ),
              // A financed receivable is still the pharmacy's to pay. Saying so
              // here stops the advance from reading as a discharge.
              if (token.state == TokenState.financed) ...[
                const SizedBox(height: Gap.sm),
                Text(
                  'A bank has advanced against this receivable. The amount '
                  'owed is unchanged.',
                  style: LaMPType.caption.copyWith(color: c.inkMuted),
                ),
              ],
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
            onPressed: () => _executePayment(state, target),
            // The button carried the amount and the method as well, at
            // seventy-seven characters over two lines. Both are on the card
            // directly above it.
            child: Text('Pay ${LaMPFormatters.formatBDT(token.declaredValue)}'),
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

  Future<void> _executePayment(LaMPState state, TokenView target) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            LampBusy(),
            SizedBox(width: Gap.lg),
            Expanded(child: Text('Submitting to the ledger')),
          ],
        ),
      ),
    );

    final res = await state.settleReceivable(
      target.tokenId,
      target.token.declaredValue,
      _payMethod,
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    setState(() {
      _payTokenId = null;
      _upgradeCaption = res.ok ? _upgradeFrom(res.result) : null;
      if (res.ok) _tab = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.ok ? 'Settled. Cycle recorded.' : (res.error ?? 'Refused')),
      ),
    );
  }

  /// The banner line for a settlement, or null when the tier did not move.
  ///
  /// `settle` returns the tier either side of the cycle it just recorded, so
  /// the banner states what actually happened rather than one fixed sentence.
  /// The advance figure is Meghna's band for the new tier, which is the curve
  /// the recourse dial on the Credit tab draws.
  String? _upgradeFrom(dynamic result) {
    if (result is! Map) return null;
    final before = result['tierBefore'];
    final after = result['tierAfter'];
    if (before is! RecourseTier || after is! RecourseTier) return null;
    if (before == after) return null;

    for (final band in SeedData.meghnaCurve.bands) {
      if (band.tier == after) {
        return 'Now ${after.label} - '
            '${band.advanceRatePct.toStringAsFixed(0)}% advance';
      }
    }
    return 'Now ${after.label}';
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
                    final open = _open(state);
                    if (open.isEmpty) return;
                    await state.raiseDispute(
                      open.first.tokenId,
                      'Damaged seals reported by ${SeedData.pharmacies[0].name}',
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
