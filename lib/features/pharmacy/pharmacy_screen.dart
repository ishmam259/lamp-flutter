import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../core/constants/ledger_labels.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/formatters.dart';
import '../../core/constants/palette.dart';
import '../../core/design/luma_press.dart';
import '../../core/design/luma_toast.dart';
import '../../core/design/luma_frost.dart';
import '../../core/constants/typography.dart';
import '../../core/models/domain_models.dart';
import '../../core/state/lamp_state.dart';
import '../../core/world/queries.dart';
import '../../core/world/seed.dart';
import '../../widgets/credit_ring.dart';
import '../../widgets/ledger_inspector_sheet.dart';
import '../../widgets/ui/lamp_ledger_ui.dart';
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
  const PharmacyScreen({super.key});

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
      // Both ends of the screen are glass, so the list has to run underneath
      // both of them — `extendBody` is the bottom half of what
      // `extendBodyBehindAppBar` does at the top.
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: LumaAppBar(
        title: pharmacy.name,
        subtitle: pharmacy.territory,
        actions: [
          LampBlockPip(
            onTap: () => LedgerInspectorSheet.show(context),
          ),
          const LampSeatMenu(),
        ],
      ),
      // No SafeArea here, deliberately. It would apply the bottom inset as
      // padding and *remove* it from the MediaQuery underneath, which is
      // exactly the padding the four lists need in order to scroll clear of
      // the nav bar rather than stopping short of it. They take it themselves,
      // through `lumaScrollPadding`.
      body: Builder(
        builder: (context) => IndexedStack(
          index: _tab,
          children: [
            _dashboard(context, state, credit),
            _creditHistory(context, credit),
            _pay(context, state),
            _disputes(context, state),
          ],
        ),
      ),
      bottomNavigationBar: LumaFrost(
        border: Border(top: BorderSide(color: c.line)),
        child: NavigationBar(
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
      padding: lumaScrollPadding(context, top: Gap.lg),
      children: [
        if (_upgradeCaption != null) ...[
          // The fact, with a dot for its state — not a green panel.
          LampCard(
            child: Row(
              children: [
                const LampStateDot(LampState.confirmed),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tier upgraded', style: LaMPType.head.copyWith(color: c.ink)),
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

        _creditCard(context, credit),
        const SizedBox(height: Gap.xl),

        LampEyebrow(
          'Due now',
          trailing: switch (open.length) {
            0 => null,
            1 => '1 invoice',
            final n => '$n invoices · ${LaMPFormatters.formatBDTCompact(owed)}',
          },
        ),
        const SizedBox(height: Gap.md),
        _dueNowCard(context, state, open.isEmpty ? null : open.first),

        const SizedBox(height: Gap.xl),
        const LampEyebrow('Recent'),
        const SizedBox(height: Gap.md),
        if (recent.isEmpty)
          Text(
            'Nothing delivered yet.',
            style: LaMPType.caption.copyWith(color: c.inkFaint),
          )
        else
          LampCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < recent.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, color: c.line),
                  _recentRow(context, recent[i], credit),
                ],
              ],
            ),
          ),
      ],
    );
  }

  /// Credit you can count: one arc per cycle, and what the next one buys.
  Widget _creditCard(BuildContext context, CreditHistory credit) {
    final c = context.lamp;
    final tier = credit.tier;
    final next = tier.index + 1 < RecourseTier.values.length
        ? RecourseTier.values[tier.index + 1]
        : null;
    final toGo = (tier.cyclesToNext ?? 0) - credit.cycles.length;
    double? nextAdvance;
    for (final band in SeedData.meghnaCurve.bands) {
      if (band.tier == next) nextAdvance = band.advanceRatePct;
    }

    return LampCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CreditRing(
                cycles: credit.cycles,
                tier: tier,
                size: 104,
                strokeWidth: 10,
              ),
              const SizedBox(width: Gap.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LampEyebrow('Credit tier'),
                    const SizedBox(height: Gap.xs),
                    Text(tier.label, style: LaMPType.title.copyWith(color: c.ink)),
                    const SizedBox(height: Gap.xs),
                    if (next != null && toGo > 0)
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: '$toGo more on-time '
                                '${toGo == 1 ? 'cycle unlocks' : 'cycles unlock'} ',
                          ),
                          TextSpan(
                            text: next.label,
                            style: LaMPType.caption.copyWith(
                              color: c.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (nextAdvance != null)
                            TextSpan(
                              text: ' — ${nextAdvance.toStringAsFixed(0)}% advance.',
                            ),
                        ]),
                        style: LaMPType.caption.copyWith(color: c.inkMuted),
                      )
                    else
                      Text(
                        tier.blurb,
                        style: LaMPType.caption.copyWith(color: c.inkMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: Gap.xl, thickness: 1, color: c.line),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Each count takes a share rather than its natural width, so a
              // wider face or a larger text scale wraps a label instead of
              // pushing History off the card.
              Expanded(
                child: _count(context, 'On time', credit.onTimeCount, c.verified),
              ),
              Expanded(
                child: _count(
                  context,
                  'Late',
                  credit.lateCount,
                  credit.lateCount > 0 ? c.pending : c.ink,
                ),
              ),
              Expanded(
                child: _count(
                  context,
                  'Defaults',
                  credit.defaultCount,
                  credit.defaultCount > 0 ? c.dispute : c.ink,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _tab = 1),
                child: const Text('History ›'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _count(BuildContext context, String label, int value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LampEyebrow(label),
        const SizedBox(height: Gap.xs),
        Text('$value', style: LaMPType.monoBody.copyWith(color: color)),
      ],
    );
  }

  /// One past or in-flight consignment.
  ///
  /// This is where a settled invoice goes when it leaves "Due now" — without
  /// it, paying makes the invoice vanish with nothing to show it landed.
  Widget _recentRow(BuildContext context, TokenView v, CreditHistory credit) {
    final c = context.lamp;
    final token = v.token;
    CreditCycle? cycle;
    for (final cc in credit.cycles) {
      if (cc.tokenId == token.tokenId) cycle = cc;
    }

    final LampState dot = switch (token.state) {
      TokenState.settled => cycle == null || cycle.onTime
          ? LampState.confirmed
          : LampState.pending,
      TokenState.disputed || TokenState.defaulted => LampState.refused,
      TokenState.delivered || TokenState.financed => LampState.confirmed,
      _ => LampState.pending,
    };

    final detail = cycle != null
        ? 'Settled ${LaMPFormatters.formatDateShort(cycle.settledAt)} · '
            '${cycle.onTime ? 'on time' : '${cycle.daysLate} days late'}'
        : '${token.state.label} · ${token.declaredCartons} '
            '${token.declaredCartons == 1 ? 'carton' : 'cartons'}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      child: Row(
        children: [
          LampStateDot(dot),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  token.invoiceId,
                  style: LaMPType.monoCaption.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LaMPType.caption.copyWith(color: c.inkFaint),
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          Text(
            LaMPFormatters.formatBDT(token.declaredValue),
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
  /// The screen used to show a pay button against a CREATED receivable — a
  /// bill for goods nobody had delivered — and to treat FINANCED as "nothing
  /// to pay", which it is not: the bank advances against the receivable to the
  /// manufacturer, and the pharmacy still owes the full amount.
  Widget _dueNowCard(BuildContext context, LaMPState state, TokenView? next) {
    final c = context.lamp;

    if (next == null) {
      return LampCard(
        child: Row(
          children: [
            const LampStateDot(LampState.confirmed),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nothing outstanding', style: LaMPType.head.copyWith(color: c.ink)),
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

    final token = next.token;
    final overdue = token.dueDate < state.now;
    final amount = LaMPFormatters.formatBDT(token.declaredValue);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
            LampStateChip(
              overdue ? LampState.refused : LampState.pending,
              LaMPFormatters.formatDaysUntil(token.dueDate, state.now),
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LampEyebrow('Amount due'),
                  const SizedBox(height: Gap.xs),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(amount, style: LaMPType.figure.copyWith(color: c.ink)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.md),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const LampEyebrow('Supplier'),
                  const SizedBox(height: Gap.xs),
                  Text(
                    SeedData.manufacturer.name,
                    textAlign: TextAlign.end,
                    style: LaMPType.caption.copyWith(color: c.ink),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        if (token.isPayable) ...[
          Row(
            children: [
              Icon(Icons.check_circle_outline, size: IconSize.sm, color: c.verified),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  'Delivery confirmed · '
                  '${token.scanned} of ${token.declaredCartons} cartons',
                  style: LaMPType.caption.copyWith(color: c.inkMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          ElevatedButton(
            onPressed: () => setState(() {
              _payTokenId = token.tokenId;
              _tab = 2;
            }),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: Text('Pay $amount'),
          ),
        ] else
          Row(
            children: [
              LampStateDot(
                token.state == TokenState.disputed ? LampState.refused : LampState.pending,
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  token.state == TokenState.disputed
                      ? 'Resolve the dispute before settling.'
                      : 'You can pay once the delivery is confirmed.',
                  style: LaMPType.caption.copyWith(color: c.inkMuted),
                ),
              ),
            ],
          ),
      ],
    );

    final tx = state.lastTxFor(token.tokenId);
    if (tx == null) return LampCard(child: body);
    return LampReceiptCard(
      tx: tx,
      onOpen: () => LedgerInspectorSheet.show(context),
      child: body,
    );
  }

  /* ---------------------------------------------------------------------- */
  /* Credit                                                                  */
  /* ---------------------------------------------------------------------- */

  Widget _creditHistory(BuildContext context, CreditHistory credit) {
    final c = context.lamp;

    return ListView(
      padding: lumaScrollPadding(context, top: Gap.lg),
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
                style: LaMPType.title.copyWith(color: c.ink),
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

        LampEyebrow('Settled cycles', trailing: '${credit.cycles.length}'),
        const SizedBox(height: Gap.md),
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
                        style: LaMPType.caption.copyWith(
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
        padding: lumaScrollPadding(context, top: Gap.lg),
        children: [
          LampCard(
            child: Row(
              children: [
                LampStateDot(waiting ? LampState.pending : LampState.confirmed),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        waiting ? 'Not payable yet' : 'Nothing to settle',
                        style: LaMPType.head.copyWith(color: c.ink),
                      ),
                      Text(
                        waiting
                            ? '${open.first.token.invoiceId} is still on its '
                                "way. You can pay once it's delivered and "
                                'confirmed.'
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
      padding: lumaScrollPadding(context, top: Gap.lg),
      children: [
        LampCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LampEyebrow('Settle'),
              const SizedBox(height: Gap.md),
              LampKeyValue(
                label: 'Invoice',
                value: token.invoiceId,
                mono: true,
              ),
              LampKeyValue(
                label: 'Amount',
                value: LaMPFormatters.formatBDT(token.declaredValue),
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

        const LampEyebrow('Pay with'),
        const SizedBox(height: Gap.md),
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
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
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
                // Dark themes' brand is near-white, so the check takes onBrand.
                ? Icon(Icons.check, size: 12, color: accent == c.brand ? c.onBrand : Colors.white) // design-lint: allow (on the bKash/Nagad logo colour)
                : null,
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              name,
              style: LaMPType.sub.copyWith(color: c.ink),
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
            Expanded(child: Text('Recording your payment…')),
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

    if (res.ok) {
      LumaHaptics.commit();
      LumaToast.show(
        context,
        'Settled. Cycle recorded.',
        icon: Icons.payments_outlined,
        tone: LumaToastTone.verified,
      );
    } else {
      LumaHaptics.reject();
      LumaToast.show(
        context,
        LedgerLabels.reason(res.error),
        icon: Icons.error_outline,
        tone: LumaToastTone.dispute,
      );
    }
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
      padding: lumaScrollPadding(context, top: Gap.lg),
      children: [
        LampCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LampEyebrow('Disputes'),
              const SizedBox(height: Gap.xs),
              Text('Raise a dispute', style: LaMPType.head.copyWith(color: c.ink)),
              const SizedBox(height: Gap.xs),
              Text(
                'Before the 24-hour window closes',
                style: LaMPType.caption.copyWith(color: c.inkFaint),
              ),
              const SizedBox(height: Gap.lg),
              SizedBox(
                width: double.infinity,
                // Refused colour on the label and outline, never as a fill.
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.dispute,
                    side: BorderSide(color: c.dispute),
                  ),
                  onPressed: () async {
                    final open = _open(state);
                    if (open.isEmpty) return;
                    await state.raiseDispute(
                      open.first.tokenId,
                      'Damaged seals reported by ${SeedData.pharmacies[0].name}',
                    );
                    if (!context.mounted) return;
                    LumaHaptics.reject();
                    LumaToast.show(
                      context,
                      'Dispute raised',
                      icon: Icons.flag_outlined,
                      tone: LumaToastTone.dispute,
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
