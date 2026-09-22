import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_theme.dart';
import '../../core/constants/palette.dart';
import '../../core/design/luma_frost.dart';
import '../../core/constants/formatters.dart';
import '../../core/chain/contract.dart';
import '../../core/models/domain_models.dart';
import '../../core/state/lamp_state.dart';
import '../../core/world/queries.dart';
import '../../core/world/seed.dart';
import '../../widgets/demo_director_sheet.dart';
import '../../widgets/ledger_inspector_sheet.dart';
import '../../widgets/recourse_dial.dart';
import '../../widgets/theme_toggle.dart';
import '../../widgets/ui/lamp_ui.dart';
import '../../core/constants/typography.dart';

class BankScreen extends StatefulWidget {
  final VoidCallback onBackToLauncher;

  const BankScreen({super.key, required this.onBackToLauncher});

  @override
  State<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends State<BankScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Msp _activeBank = Msp.meghnaMSP;
  String? _executionBanner;
  bool _isSuccessBanner = false;
  bool _isAdvancing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// The curve the active bank has registered with the consortium. Used to
  /// drive the rate dial and to derive the per-tier advance rate and fee that
  /// the financing card displays — so switching Meghna → Padma actually
  /// changes the pricing.
  RateCurve _activeCurve() {
    return _activeBank == Msp.meghnaMSP
        ? SeedData.meghnaCurve
        : SeedData.padmaCurve;
  }

  /// The tier this counterparty has earned, read from its own credit key.
  ///
  /// Was `state.creditHistory?.tier` — the one cached history, which belongs
  /// to the demo pharmacy. Every other counterparty was priced as though it
  /// had Rahman Medical Hall's record.
  RecourseTier _tierFor(LaMPState state, String buyerDid) =>
      state.creditFor(buyerDid)?.tier ?? RecourseTier.newTier;

  /// The band on the active bank's curve that covers this receivable, or null
  /// when none does.
  ///
  /// Null is the honest answer and the card says so: `matchAndAdvance` walks
  /// the same bands and refuses when no band covers the counterparty at this
  /// invoice size. The previous version ended in a `firstWhere` with no
  /// `orElse`, which threw a `StateError` inside `build` instead.
  RateCurveBand? _bandFor(LaMPState state, ReceivableToken token) {
    final tier = _tierFor(state, token.buyerDid);
    for (final band in _activeCurve().bands) {
      if (band.tier == tier && token.declaredValue <= band.maxInvoiceValue) {
        return band;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // The Scaffold is built below the Theme, not beside it. Built here, every
    // `context.lamp` in this screen would read the application's palette
    // rather than this seat's, and the world theme would apply to nothing.
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
      // One bar for all five seats — see `LumaAppBar`. This one used to set
      // `elevation: 1`, which gave it a drop shadow no other screen had; the
      // separation is now a hairline under glass, and the content scrolls
      // visibly beneath it.
      appBar: LumaAppBar(
        title: 'Financing',
        subtitle: 'Consortium endorser',
        onBack: widget.onBackToLauncher,
        actions: [
          const ThemeToggle(),
          // Which bank's seat this is. An inline dropdown spelled the name
          // out in the bar and took about 140dp of a 360dp phone, leaving
          // the title less room than its own leading mark needed. A menu
          // costs one tap and holds the same two choices.
          PopupMenuButton<Msp>(
            tooltip: 'Switch seat',
            initialValue: _activeBank,
            onSelected: (v) => setState(() => _activeBank = v),
            icon: const Icon(Icons.swap_horiz),
            itemBuilder: (_) => const [
              PopupMenuItem(value: Msp.meghnaMSP, child: Text('Meghna Bank')),
              PopupMenuItem(value: Msp.padmaMSP, child: Text('Padma Bank')),
            ],
          ),
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
        ],
        // Colours come from `tabBarTheme` now; the three screens that had a
        // TabBar were each setting the same three by hand.
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Financing'),
            Tab(text: 'Rate curve'),
            Tab(text: 'Portfolio'),
          ],
        ),
      ),
        // The Builder is load-bearing: under it, `MediaQuery.padding.top`
        // carries the height of the bar and its tab strip, which is what
        // `lumaScrollPadding` reads in each tab below.
        body: Builder(
          builder: (context) => TabBarView(
            controller: _tabController,
            children: [
              _buildOpportunitiesTab(context, state),
              _buildRateCurveTab(context, state),
              _buildPortfolioTab(context, state),
            ],
          ),
        ),
    );
  }

  /// The financing queue, partitioned the way the chaincode partitions it.
  ///
  /// Three sections, mirroring `app/bank/opportunities/page.tsx:35-47`:
  /// what can be financed now, what is still inside its objection period, and
  /// what has already been advanced against. A financed receivable used to
  /// stay in the queue with a live Finance button, so the only way to discover
  /// it had moved on was to press it and read the refusal.
  Widget _buildOpportunitiesTab(BuildContext context, LaMPState state) {
    final now = state.now;
    final views = state.tokenViews;

    final eligible = <TokenView>[];
    final waiting = <TokenView>[];
    for (final v in views) {
      if (v.token.isFinanceable(now)) {
        eligible.add(v);
      } else if (v.token.isAwaitingWindow(now)) {
        waiting.add(v);
      }
    }
    final financed = views
        .where((v) => v.token.state == TokenState.financed)
        .take(4)
        .toList();

    return SingleChildScrollView(
      padding: lumaScrollPadding(context, top: Gap.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_executionBanner != null) _buildExecutionBanner(context),

              _sectionHead(
                context,
                'Eligible for financing',
                eligible.length,
                'Delivery confirmed, dispute window closed, no dispute raised',
              ),
              if (eligible.isEmpty)
                _emptyCard(
                  context,
                  'Nothing eligible yet. A delivered receivable becomes '
                  'financeable once its 24-hour dispute window closes — '
                  'advance the clock from the demo director.',
                )
              else
                for (final v in eligible) ...[
                  _opportunityCard(context, state, v, eligible: true),
                  const SizedBox(height: 12),
                ],

              if (waiting.isNotEmpty) ...[
                const SizedBox(height: 12),
                _sectionHead(
                  context,
                  'Awaiting dispute window',
                  waiting.length,
                  'Cash is never released against a delivery that has not '
                  'achieved finality',
                ),
                for (final v in waiting) ...[
                  _opportunityCard(context, state, v, eligible: false),
                  const SizedBox(height: 12),
                ],
              ],

              if (financed.isNotEmpty) ...[
                const SizedBox(height: 12),
                _sectionHead(
                  context,
                  'Recently financed',
                  financed.length,
                  'One invoice carries one token — a second advance cannot be '
                  'drawn',
                ),
                for (final v in financed) ...[
                  _financedCard(context, v),
                  const SizedBox(height: 12),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHead(
    BuildContext context,
    String title,
    int count,
    String hint,
  ) {
    final c = context.lamp;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // Flexible, not fixed: "Awaiting dispute window" and its count
              // ran 5.8 pixels off a 360dp phone. A section heading that wraps
              // beats one that is clipped.
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: c.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: LaMPType.mono,
                  fontFamilyFallback: LaMPType.fallback,
                  color: c.inkFaint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(hint, style: TextStyle(fontSize: 11, color: c.inkFaint)),
        ],
      ),
    );
  }

  Widget _emptyCard(BuildContext context, String message) {
    final c = context.lamp;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.line),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, height: 1.5, color: c.inkFaint),
      ),
    );
  }

  /// One receivable, with the preconditions the chaincode will check.
  ///
  /// Every row is computed. They were not: "Not already financed" was written
  /// `isPassed: true` regardless, and "Dispute window closed" compared the
  /// off-chain delivery status instead of the clock, so the card could claim
  /// finality it had not checked. The button is disabled when any of them
  /// fails, rather than submitting and reporting the refusal afterwards.
  Widget _opportunityCard(
    BuildContext context,
    LaMPState state,
    TokenView view, {
    required bool eligible,
  }) {
    final c = context.lamp;
    final token = view.token;
    final now = state.now;
    final tier = _tierFor(state, token.buyerDid);
    final band = _bandFor(state, token);

    final ratio = token.deliveryRatio;
    final confirmed = ratio >= LaMPContract.confirmationThreshold;
    final windowClosed = token.disputeWindowClosed(now);
    final notFinanced = token.financing == null;
    final remaining = token.millisUntilWindowCloses(now);

    final advanceAmount = band == null
        ? 0.0
        : (token.declaredValue * band.advanceRatePct / 100.0).roundToDouble();

    final canFinance = eligible && band != null && !_isAdvancing;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  token.invoiceId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: LaMPType.mono,
                    fontFamilyFallback: LaMPType.fallback,
                    color: c.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                LaMPFormatters.formatBDT(token.declaredValue),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: c.brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LampChip(
            label: eligible ? 'SCF eligible' : 'In objection period',
            tone: eligible ? LampTone.verified : LampTone.pending,
          ),
          const SizedBox(height: 8),
          Text(
            '${view.pharmacy?.name ?? token.buyerDid} · '
            '${view.pharmacy?.territory ?? ''}',
            style: TextStyle(fontSize: 12, color: c.inkMuted),
          ),
          const SizedBox(height: 16),
          Divider(color: c.line, height: 1),
          const SizedBox(height: 16),

          Text(
            'Before financing',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: c.inkFaint,
            ),
          ),
          const SizedBox(height: 8),

          _checkItem(
            context,
            label: 'Delivery confirmed',
            detail: '${token.scanned} of ${token.declaredCartons} cartons · '
                '${(ratio * 100).toInt()}% against a '
                '${(LaMPContract.confirmationThreshold * 100).toInt()}% threshold',
            isPassed: confirmed,
          ),
          _checkItem(
            context,
            label: 'No dispute raised',
            detail: token.state == TokenState.disputed
                ? token.disputeReason ?? 'Dispute open'
                : 'No objections filed',
            isPassed: token.state != TokenState.disputed,
          ),
          _checkItem(
            context,
            label: 'Not already financed',
            detail: notFinanced
                ? 'No prior advance'
                : 'Advanced by '
                    '${token.financing!.bankMsp.shortName}',
            isPassed: notFinanced,
          ),
          _checkItem(
            context,
            label: 'Dispute window closed',
            detail: windowClosed
                ? 'Window closed'
                : 'Closes in ${LaMPFormatters.formatDuration(remaining)}',
            isPassed: windowClosed,
          ),

          const SizedBox(height: 20),

          if (band == null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.pendingSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'No band on your curve covers a '
                '${tier.label.toLowerCase()} counterparty at this invoice '
                'size.',
                style: TextStyle(fontSize: 11, color: c.pending),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  _statItem(context, 'Tier', tier.label, c.brand),
                  _statItem(context, 'Advance',
                      '${band.advanceRatePct.toStringAsFixed(1)}%', c.ink),
                  _statItem(context, 'Fee',
                      '${band.feePct.toStringAsFixed(1)}%', c.pending),
                  _statItem(
                    context,
                    'They receive',
                    LaMPFormatters.formatBDT(advanceAmount),
                    c.verified,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canFinance
                  ? () => _executeSmartContractAdvance(
                        state,
                        token.tokenId,
                        advanceAmount,
                      )
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
                  : const Icon(Icons.flash_on),
              label: Text(
                _isAdvancing
                    ? 'Submitting...'
                    : band == null
                        ? 'No band covers this receivable'
                        : 'Finance ${LaMPFormatters.formatBDT(advanceAmount)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.brand,
                foregroundColor: c.onBrand,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          if (!eligible && band != null) ...[
            const SizedBox(height: 8),
            Text(
              'The chaincode refuses until the window closes.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: c.inkFaint),
            ),
          ],
        ],
      ),
    );
  }

  /// A receivable this consortium has already advanced against.
  ///
  /// It carries no Finance button: one invoice carries one token, and a second
  /// advance cannot be drawn.
  Widget _financedCard(BuildContext context, TokenView view) {
    final c = context.lamp;
    final token = view.token;
    final f = token.financing;
    if (f == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  token.invoiceId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: LaMPType.mono,
                    fontFamilyFallback: LaMPType.fallback,
                    color: c.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              LampChip(
                label: f.bankMsp == _activeBank
                    ? 'financed by you'
                    : f.bankMsp.shortName,
                tone: f.bankMsp == _activeBank
                    ? LampTone.verified
                    : LampTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            view.pharmacy?.name ?? token.buyerDid,
            style: TextStyle(fontSize: 12, color: c.inkMuted),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _statItem(context, 'Advance',
                  '${f.advanceRatePct.toStringAsFixed(1)}%', c.verified),
              _statItem(
                  context, 'Fee', '${f.feePct.toStringAsFixed(1)}%', c.pending),
              _statItem(
                context,
                'Advanced',
                LaMPFormatters.formatBDTCompact(f.advancedAmount),
                c.ink,
              ),
              _statItem(
                context,
                'Invoice',
                LaMPFormatters.formatBDTCompact(token.declaredValue),
                c.ink,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Transient banner that surfaces the most recent chaincode result on the
  /// financing tab. Extracted so both the active opportunity card and the
  /// closed-state empty-state can show the same banner.
  Widget _buildExecutionBanner(BuildContext context) {
    final c = context.lamp;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isSuccessBanner ? c.verifiedSoft : c.disputeSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _isSuccessBanner ? c.verified : c.dispute),
      ),
      child: Row(
        children: [
          Icon(
            _isSuccessBanner ? Icons.check_circle : Icons.warning_rounded,
            color: _isSuccessBanner ? c.verified : c.dispute,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _executionBanner!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _isSuccessBanner ? c.verified : c.dispute,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => setState(() => _executionBanner = null),
          ),
        ],
      ),
    );
  }

  /// One financing precondition: the rule, and how this receivable measures
  /// against it.
  ///
  /// Label and detail stack rather than sitting either side of a Spacer. Side
  /// by side they overflowed a phone by 236 pixels — a Spacer distributes free
  /// space and does nothing when there is none — and the detail is the half
  /// that carries the numbers, so truncating it would have been worse than the
  /// overflow it replaced.
  Widget _checkItem(BuildContext context,
      {required String label, required String detail, required bool isPassed}) {
    final c = context.lamp;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              isPassed ? Icons.check_circle : Icons.hourglass_empty,
              size: 16,
              color: isPassed ? c.verified : c.pending,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: c.inkFaint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(BuildContext context, String label, String value, Color color) {
    final c = context.lamp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: c.inkFaint)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  void _executeSmartContractAdvance(
    LaMPState state,
    String tokenId,
    double advanceAmount,
  ) async {
    if (_isAdvancing) return;
    setState(() => _isAdvancing = true);
    try {
      final res = await state.financeReceivable(tokenId, _activeBank);
      if (!mounted) return;
      setState(() {
        if (res.ok) {
          _isSuccessBanner = true;
          _executionBanner =
              'SMART CONTRACT FINANCING EXECUTED: Advance of ${LaMPFormatters.formatBDT(advanceAmount)} committed on block #${res.tx.blockNumber} by ${_activeBank.shortName}!';
        } else {
          _isSuccessBanner = false;
          _executionBanner = 'CHAINCODE REFUSAL: ${res.error} (Recorded in block #${res.tx.blockNumber} for audit)';
        }
      });
    } finally {
      if (mounted) setState(() => _isAdvancing = false);
    }
  }

  Widget _buildRateCurveTab(BuildContext context, LaMPState state) {
    final c = context.lamp;
    return SingleChildScrollView(
      padding: lumaScrollPadding(context, top: Gap.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rate curve',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.ink)),
                    const SizedBox(height: 4),
                    Text(
                      'Repayment history moves risk to the bank.',
                      style: TextStyle(fontSize: 12, color: c.inkMuted),
                    ),
                    const SizedBox(height: 16),
                    RecourseDial(
                      bands: _activeCurve().bands,
                      currentTier: state.creditHistory?.tier ?? RecourseTier.building,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The book, computed from the ledger.
  ///
  /// Was two string literals — "45,00,000 across 18 pharmacies" and a 0.0%
  /// default rate — on a tab that took `state` and never read it.
  Widget _buildPortfolioTab(BuildContext context, LaMPState state) {
    final c = context.lamp;
    final views = state.tokenViews;

    final financed = views.where((v) => v.token.isFinanced).toList();
    final outstanding = financed
        .where((v) => v.token.state != TokenState.settled)
        .toList();

    final advanced = financed.fold<double>(
      0.0,
      (sum, TokenView v) => sum + (v.token.financing?.advancedAmount ?? 0.0),
    );
    final atRisk = outstanding.fold<double>(
      0.0,
      (sum, TokenView v) => sum + (v.token.financing?.advancedAmount ?? 0.0),
    );
    final counterparties =
        financed.map((v) => v.token.buyerDid).toSet().length;
    final settled = financed.length - outstanding.length;
    final defaults =
        views.where((v) => v.token.state == TokenState.defaulted).length;
    final defaultRate = financed.isEmpty
        ? 0.0
        : defaults / financed.length * 100.0;

    return SingleChildScrollView(
      padding: lumaScrollPadding(context, top: Gap.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Portfolio',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Exposure across financed receivables.',
                      style: TextStyle(fontSize: 12, color: c.inkMuted),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 24,
                      runSpacing: 16,
                      children: [
                        _statItem(
                          context,
                          'Advanced to date',
                          LaMPFormatters.formatBDTCompact(advanced),
                          c.brand,
                        ),
                        _statItem(
                          context,
                          'Outstanding',
                          LaMPFormatters.formatBDTCompact(atRisk),
                          c.ink,
                        ),
                        _statItem(
                          context,
                          'Counterparties',
                          '$counterparties',
                          c.ink,
                        ),
                        _statItem(
                          context,
                          'Repaid',
                          '$settled of ${financed.length}',
                          c.verified,
                        ),
                        _statItem(
                          context,
                          'Default rate',
                          '${defaultRate.toStringAsFixed(1)}%',
                          defaults == 0 ? c.verified : c.dispute,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sectionHead(
                context,
                'Outstanding advances',
                outstanding.length,
                'Cash out against a receivable the pharmacy has yet to settle',
              ),
              if (outstanding.isEmpty)
                _emptyCard(
                  context,
                  'Nothing outstanding. Every receivable this consortium has '
                  'financed has been repaid.',
                )
              else
                for (final v in outstanding) ...[
                  _financedCard(context, v),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }
}
