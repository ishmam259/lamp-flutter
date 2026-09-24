import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/ledger_labels.dart';
import '../../core/constants/app_theme.dart';
import '../../core/constants/palette.dart';
import '../../core/design/luma_frost.dart';
import '../../core/design/luma_press.dart';
import '../../core/design/luma_toast.dart';
import '../../core/constants/formatters.dart';
import '../../core/chain/contract.dart';
import '../../core/models/domain_models.dart';
import '../../core/state/lamp_state.dart';
import '../../core/world/queries.dart';
import '../../core/world/seed.dart';
import '../../widgets/ledger_inspector_sheet.dart';
import '../../widgets/ui/lamp_ledger_ui.dart';
import '../../widgets/ui/lamp_ui.dart';
import 'verify_anchor_sheet.dart';
import '../../core/constants/typography.dart';

/// A bank's trade-finance desk: the queue of invoices it can finance, its
/// rate card, and what it has out.
///
/// The queue is partitioned the way the chaincode partitions it — ready now,
/// waiting for the dispute window, already financed — and every check on a
/// ready invoice is computed, so the Finance button is only live when the
/// ledger will accept it.
class BankScreen extends StatefulWidget {
  /// Which bank's desk this is — the signed-in account's bank.
  final Msp? initialBank;

  const BankScreen({super.key, this.initialBank});

  @override
  State<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends State<BankScreen> {
  /// Queue, Rates, Portfolio.
  int _tab = 0;
  late final Msp _bank = widget.initialBank ?? Msp.meghnaMSP;
  bool _isAdvancing = false;

  /// The curve this bank has registered with the consortium; it prices every
  /// card on the queue.
  RateCurve get _curve =>
      _bank == Msp.meghnaMSP ? SeedData.meghnaCurve : SeedData.padmaCurve;

  /// The tier this counterparty has earned, read from its own credit record.
  RecourseTier _tierFor(LaMPState state, String buyerDid) =>
      state.creditFor(buyerDid)?.tier ?? RecourseTier.newTier;

  /// The band on this bank's curve that covers the invoice, or null when none
  /// does — `matchAndAdvance` walks the same bands and refuses in that case.
  RateCurveBand? _bandFor(LaMPState state, ReceivableToken token) {
    final tier = _tierFor(state, token.buyerDid);
    for (final band in _curve.bands) {
      if (band.tier == tier && token.declaredValue <= band.maxInvoiceValue) {
        return band;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // The Scaffold is built below the Theme so `context.lamp` reads this
    // seat's palette.
    return Theme(
      data: LaMPTheme.of(context, LampWorld.portal),
      child: Builder(builder: _buildScaffold),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final state = context.watch<LaMPState>();
    final c = context.lamp;

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: LumaAppBar(
        title: '${_bank.shortName} Bank',
        subtitle: 'Trade finance',
        actions: [
          LampBlockPip(onTap: () => LedgerInspectorSheet.show(context)),
          const LampSeatMenu(),
        ],
      ),
      body: Builder(
        builder: (context) => IndexedStack(
          index: _tab,
          children: [
            _queueTab(context, state),
            _ratesTab(context, state),
            _portfolioTab(context, state),
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
              icon: Icon(Icons.inbox_outlined),
              selectedIcon: Icon(Icons.inbox),
              label: 'Queue',
            ),
            NavigationDestination(
              icon: Icon(Icons.percent_outlined),
              label: 'Rates',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Portfolio',
            ),
          ],
        ),
      ),
    );
  }

  /* ---------------------------------------------------------------------- */
  /* Queue                                                                   */
  /* ---------------------------------------------------------------------- */

  Widget _queueTab(BuildContext context, LaMPState state) {
    final now = state.now;
    final views = state.tokenViews;
    final ready = [for (final v in views) if (v.token.isFinanceable(now)) v];
    final waiting = [for (final v in views) if (v.token.isAwaitingWindow(now)) v];
    final financed = [
      for (final v in views)
        if (v.token.state == TokenState.financed) v,
    ].take(4).toList();
    final deployed = views
        .where((v) => v.token.financing?.bankMsp == _bank)
        .fold<double>(0, (s, v) => s + v.token.financing!.advancedAmount);

    return ListView(
      padding: lumaScrollPadding(context, top: Gap.lg),
      children: [
        LampCard(
          child: Row(
            children: [
              Expanded(child: _figure(context, 'Ready', '${ready.length}')),
              Expanded(child: _figure(context, 'Waiting', '${waiting.length}')),
              Expanded(
                flex: 2,
                child: _figure(
                  context,
                  'Deployed',
                  LaMPFormatters.formatBDTCompact(deployed),
                  end: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.xl),
        LampEyebrow('Ready to finance', trailing: '${ready.length}'),
        const SizedBox(height: Gap.md),
        if (ready.isEmpty)
          const LampEmpty(
            icon: Icons.inbox_outlined,
            title: 'Nothing ready yet',
            message: 'A delivered invoice can be financed once its 24-hour '
                'dispute window closes.',
          )
        else
          for (final v in ready) ...[
            _readyCard(context, state, v),
            const SizedBox(height: Gap.md),
          ],
        if (waiting.isNotEmpty) ...[
          const SizedBox(height: Gap.lg),
          LampEyebrow('Dispute window open', trailing: '${waiting.length}'),
          const SizedBox(height: Gap.md),
          _rows(context, [
            for (final v in waiting)
              _row(
                context,
                view: v,
                dot: LampState.pending,
                detail: '${v.pharmacy?.name ?? 'Pharmacy'} · window closes in '
                    '${LaMPFormatters.formatDuration(v.token.millisUntilWindowCloses(now))}',
                amount: LaMPFormatters.formatBDT(v.token.declaredValue),
              ),
          ]),
        ],
        if (financed.isNotEmpty) ...[
          const SizedBox(height: Gap.xl),
          LampEyebrow('Recently financed', trailing: '${financed.length}'),
          const SizedBox(height: Gap.md),
          _rows(context, [
            for (final v in financed) _financedRow(context, v),
          ]),
        ],
      ],
    );
  }

  Widget _figure(BuildContext context, String label, String value, {bool end = false}) {
    final c = context.lamp;
    return Column(
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        LampEyebrow(label),
        const SizedBox(height: Gap.xs),
        Text(value, style: LaMPType.figure.copyWith(color: c.ink)),
      ],
    );
  }

  /// An invoice the bank can finance now: the checks the ledger will run,
  /// the price on this bank's curve, and the button.
  Widget _readyCard(BuildContext context, LaMPState state, TokenView view) {
    final c = context.lamp;
    final token = view.token;
    final now = state.now;
    final tier = _tierFor(state, token.buyerDid);
    final band = _bandFor(state, token);

    final delivered = token.deliveryRatio >= LaMPContract.confirmationThreshold;
    final undisputed = token.state != TokenState.disputed;
    final notFinanced = token.financing == null;
    final windowClosed = token.disputeWindowClosed(now);
    // The chaincode refuses an advance without an anchored PDF, so the card
    // has to show that precondition and hold the button back, or the button
    // would look live and then be refused.
    final documentAnchored = token.documentHash != null;
    final passed = [delivered, undisputed, notFinanced, windowClosed, documentAnchored]
        .where((x) => x)
        .length;

    final advance = band == null
        ? 0.0
        : (token.declaredValue * band.advanceRatePct / 100.0).roundToDouble();
    final closedFor = token.disputeWindowClosesAt == null
        ? null
        : now - token.disputeWindowClosesAt!;

    final canFinance = band != null && documentAnchored && !_isAdvancing;

    return LampCard(
      child: Column(
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
              Text(
                LaMPFormatters.formatBDT(token.declaredValue),
                style: LaMPType.monoBody.copyWith(
                  color: c.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Text(
            '${view.pharmacy?.name ?? 'Pharmacy'} · ${view.pharmacy?.territory ?? ''}',
            style: LaMPType.caption.copyWith(color: c.inkMuted),
          ),
          Divider(height: Gap.xl, thickness: 1, color: c.line),
          LampEyebrow('Checks · $passed of 5 passed'),
          const SizedBox(height: Gap.sm),
          _check(context, 'Delivery confirmed',
              '${token.scanned}/${token.declaredCartons} · ${(token.deliveryRatio * 100).round()}%',
              delivered),
          _check(context, 'No dispute raised', undisputed ? 'none' : 'open', undisputed),
          _check(context, 'Not already financed',
              notFinanced ? 'no prior advance' : token.financing!.bankMsp.shortName, notFinanced),
          _check(
            context,
            'Dispute window closed',
            windowClosed
                ? (closedFor == null ? 'closed' : '${LaMPFormatters.formatDuration(closedFor)} ago')
                : 'in ${LaMPFormatters.formatDuration(token.millisUntilWindowCloses(now))}',
            windowClosed,
          ),
          _check(
            context,
            'Invoice PDF anchored',
            documentAnchored
                ? '${token.documentHash!.substring(0, 8)}… · ${token.documentByteLength ?? 0} B'
                : 'not yet',
            documentAnchored,
          ),
          Divider(height: Gap.xl, thickness: 1, color: c.line),
          if (band == null)
            Row(
              children: [
                const LampStateDot(LampState.pending),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    'Your rate card has no band for a ${tier.label.toLowerCase()} '
                    'pharmacy at this invoice size.',
                    style: LaMPType.caption.copyWith(color: c.inkMuted),
                  ),
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _price(context, 'Tier', tier.label, mono: false)),
                Expanded(
                  flex: 3,
                  child: _price(context, 'Advance', '${band.advanceRatePct.toStringAsFixed(1)}%'),
                ),
                Expanded(
                  flex: 2,
                  child: _price(context, 'Fee', '${band.feePct.toStringAsFixed(1)}%'),
                ),
                Expanded(
                  flex: 4,
                  child: _price(
                    context,
                    'Paid out',
                    LaMPFormatters.formatBDT(advance),
                    end: true,
                  ),
                ),
              ],
            ),
          const SizedBox(height: Gap.lg),
          ElevatedButton.icon(
            onPressed: canFinance
                ? () => _finance(state, token.tokenId, advance)
                : null,
            icon: _isAdvancing
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(c.onBrand),
                    ),
                  )
                : const Icon(Icons.payments_outlined, size: IconSize.md),
            label: Text(
              _isAdvancing
                  ? 'Financing…'
                  : band == null
                      ? 'No rate for this invoice'
                      : !documentAnchored
                          ? 'Anchor the invoice PDF first'
                          : 'Finance ${LaMPFormatters.formatBDT(advance)}',
            ),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: Gap.sm),
          // Opens the sheet that walks the financier through pick a PDF →
          // hash → match verdict → anchor on the channel → download. Offered
          // whether or not the other checks pass, so a bank can anchor ahead
          // of the dispute window closing.
          OutlinedButton.icon(
            key: ValueKey('verify-pdf-${token.tokenId}'),
            icon: const Icon(Icons.verified_outlined, size: IconSize.md),
            label: Text(
              documentAnchored ? 'Re-verify & download PDF' : 'Verify & download PDF',
            ),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            onPressed: () => _openVerifySheet(state, token.tokenId),
          ),
        ],
      ),
    );
  }

  Widget _check(BuildContext context, String label, String detail, bool ok) {
    final c = context.lamp;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.schedule,
            size: IconSize.sm,
            color: ok ? c.verified : c.pending,
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(label, style: LaMPType.body.copyWith(color: c.ink)),
          ),
          const SizedBox(width: Gap.sm),
          Text(
            detail,
            style: LaMPType.monoCaption.copyWith(color: ok ? c.inkMuted : c.pending),
          ),
        ],
      ),
    );
  }

  Widget _price(BuildContext context, String label, String value,
      {bool mono = true, bool end = false}) {
    final c = context.lamp;
    return Column(
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, maxLines: 1, style: LaMPType.caption.copyWith(color: c.inkFaint)),
        const SizedBox(height: Gap.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: end ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: (mono ? LaMPType.monoBody : LaMPType.sub).copyWith(color: c.ink),
          ),
        ),
      ],
    );
  }

  /// A list of compact rows in one card, hairlines between.
  Widget _rows(BuildContext context, List<Widget> rows) {
    final c = context.lamp;
    return LampCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: c.line),
            rows[i],
          ],
        ],
      ),
    );
  }

  /* ---------------------------------------------------------------------- */
  /* Verify / Anchor / Download sheet                                        */
  /* ---------------------------------------------------------------------- */

  /// Open the verify modal bottom sheet for the given token.
  ///
  /// The sheet hosts the file picker, the SHA-256 comparison verdict, the
  /// optional anchor-on-channel button, and the share-sheet download. Stays
  /// modal so the financier can't finance from behind it; dismissal returns
  /// to the opportunity card with the new `documentHash` already populated.
  void _openVerifySheet(LaMPState state, String tokenId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.lamp.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => VerifyAndAnchorSheet(
        state: state,
        tokenId: tokenId,
        activeBank: _bank,
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required TokenView view,
    required LampState dot,
    required String detail,
    required String amount,
  }) {
    final c = context.lamp;
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
                  view.token.invoiceId,
                  style: LaMPType.monoCaption.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: LaMPType.caption.copyWith(color: c.inkFaint),
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          Text(amount, style: LaMPType.monoCaption.copyWith(color: c.ink)),
        ],
      ),
    );
  }

  /// A financed invoice: who financed it, at what rate, for how much. It has
  /// no button — each invoice can be financed only once.
  Widget _financedRow(BuildContext context, TokenView view) {
    final f = view.token.financing!;
    final byUs = f.bankMsp == _bank;
    return _row(
      context,
      view: view,
      dot: LampState.confirmed,
      detail: '${view.pharmacy?.name ?? 'Pharmacy'} · '
          '${byUs ? 'financed by you' : 'financed by ${f.bankMsp.shortName}'} · '
          '${f.advanceRatePct.toStringAsFixed(0)}% advance',
      amount: LaMPFormatters.formatBDT(f.advancedAmount),
    );
  }

  Future<void> _finance(LaMPState state, String tokenId, double advance) async {
    if (_isAdvancing) return;
    setState(() => _isAdvancing = true);
    try {
      final res = await state.financeReceivable(tokenId, _bank);
      if (!mounted) return;
      if (res.ok) {
        LumaHaptics.commit();
        LumaToast.show(
          context,
          'Financed · ${LaMPFormatters.formatBDT(advance)} to ${Msp.manufacturerMSP.shortName}',
          icon: Icons.check_circle_outline,
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
    } finally {
      if (mounted) setState(() => _isAdvancing = false);
    }
  }

  /* ---------------------------------------------------------------------- */
  /* Rates                                                                   */
  /* ---------------------------------------------------------------------- */

  /// This bank's rate card: what it advances, what it charges, and how much
  /// the manufacturer still guarantees, at each credit tier.
  ///
  /// There used to be a dial above this table as well, drawing the same four
  /// bands in tiles too narrow for their labels and highlighting one seeded
  /// pharmacy's tier, which meant nothing on a bank's own card.
  Widget _ratesTab(BuildContext context, LaMPState state) {
    final c = context.lamp;
    Widget cell(String text, {int flex = 2, bool mono = true, TextAlign align = TextAlign.end, Color? color}) =>
        Expanded(
          flex: flex,
          child: Text(
            text,
            textAlign: align,
            style: (mono ? LaMPType.monoCaption : LaMPType.sub).copyWith(color: color ?? c.inkMuted),
          ),
        );

    return ListView(
      padding: lumaScrollPadding(context, top: Gap.lg),
      children: [
        const LampEyebrow('Your rate card'),
        const SizedBox(height: Gap.xs),
        Text(
          'The better a pharmacy repays, the more you advance and the less the '
          'manufacturer has to guarantee.',
          style: LaMPType.caption.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: Gap.md),
        _rows(context, [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
            child: Row(children: [
              cell('Tier', flex: 3, mono: false, align: TextAlign.start, color: c.inkFaint),
              cell('Advance', color: c.inkFaint),
              cell('Fee', color: c.inkFaint),
              cell('Guarantee', flex: 3, color: c.inkFaint),
            ]),
          ),
          for (final b in _curve.bands)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
              child: Row(children: [
                cell(b.tier.label, flex: 3, mono: false, align: TextAlign.start, color: c.ink),
                cell('${b.advanceRatePct.round()}%', color: c.ink),
                cell('${b.feePct.toStringAsFixed(1)}%'),
                cell('${b.manufacturerRecoursePct.round()}%', flex: 3),
              ]),
            ),
        ]),
        const SizedBox(height: Gap.sm),
        Text(
          'Guarantee is the share of an unpaid advance the manufacturer covers.',
          style: LaMPType.caption.copyWith(color: c.inkFaint),
        ),
      ],
    );
  }

  /* ---------------------------------------------------------------------- */
  /* Portfolio                                                               */
  /* ---------------------------------------------------------------------- */

  /// What this bank has out, computed from the ledger.
  Widget _portfolioTab(BuildContext context, LaMPState state) {
    final c = context.lamp;
    final views = state.tokenViews;
    final ours = views.where((v) => v.token.financing?.bankMsp == _bank).toList();
    final outstanding =
        ours.where((v) => v.token.state != TokenState.settled).toList();
    final advanced = ours.fold<double>(0, (s, v) => s + v.token.financing!.advancedAmount);
    final atRisk =
        outstanding.fold<double>(0, (s, v) => s + v.token.financing!.advancedAmount);
    final repaid = ours.length - outstanding.length;
    final defaults = ours.where((v) => v.token.state == TokenState.defaulted).length;

    return ListView(
      padding: lumaScrollPadding(context, top: Gap.lg),
      children: [
        LampCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LampEyebrow('Outstanding'),
              const SizedBox(height: Gap.xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  LaMPFormatters.formatBDT(atRisk),
                  style: LaMPType.displayFigure.copyWith(color: c.ink),
                ),
              ),
              Text(
                '${outstanding.length} unpaid ${outstanding.length == 1 ? 'advance' : 'advances'}',
                style: LaMPType.caption.copyWith(color: c.inkFaint),
              ),
              Divider(height: Gap.xl, thickness: 1, color: c.line),
              Row(
                children: [
                  Expanded(
                    child: _price(context, 'Advanced to date',
                        LaMPFormatters.formatBDTCompact(advanced)),
                  ),
                  Expanded(child: _price(context, 'Repaid', '$repaid of ${ours.length}')),
                  Expanded(
                    child: _price(context, 'Defaults', '$defaults', end: true),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.xl),
        LampEyebrow('Unpaid advances', trailing: '${outstanding.length}'),
        const SizedBox(height: Gap.md),
        if (outstanding.isEmpty)
          const LampEmpty(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Nothing outstanding',
            message: 'Every invoice you financed has been repaid.',
          )
        else
          _rows(context, [for (final v in outstanding) _financedRow(context, v)]),
      ],
    );
  }
}
