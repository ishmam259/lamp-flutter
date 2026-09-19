import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_theme.dart';
import '../../core/constants/palette.dart';
import '../../core/design/luma_frost.dart';
import '../../core/constants/formatters.dart';
import '../../core/models/domain_models.dart';
import '../../core/state/lamp_state.dart';
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
    final delivery = state.getDelivery(state.demoTokenId);
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
              _buildOpportunitiesTab(context, state, delivery),
              _buildRateCurveTab(context, state),
              _buildPortfolioTab(context, state),
            ],
          ),
        ),
    );
  }

  Widget _buildOpportunitiesTab(BuildContext context, LaMPState state, Delivery? delivery) {
    final c = context.lamp;
    final scannedCount = delivery?.cartons.where((c) => c.scannedAt != null).length ?? 0;
    final totalCartons = delivery?.cartons.length ?? 25;
    final deliveryRatio = totalCartons > 0 ? scannedCount / totalCartons : 0.0;
    final isDeliveryConfirmed = deliveryRatio >= 0.90;

    // Check dispute window
    final disputeWindowClosed = (delivery?.status == DeliveryStatus.completed);

    return SingleChildScrollView(
      padding: lumaScrollPadding(context, top: Gap.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Result Banner
              if (_executionBanner != null)
                Container(
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
                ),

              // Opportunity Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Id and amount share the row; the eligibility chip takes
                    // the line beneath. All three abreast needed about 200dp
                    // of the 180dp available and overflowed by 210.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            state.demoInvoiceId,
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
                          LaMPFormatters.formatBDT(182400),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.brand),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const LampChip(label: 'SCF eligible', tone: LampTone.verified),
                    const SizedBox(height: 8),
                    // "Buyer: X · Seller: Y · Z" was sixty-six characters
                    // restating a relationship the portal never varies.
                    Text(
                      'Rahman Medical Hall · Bogura Sadar',
                      style: TextStyle(fontSize: 12, color: c.inkMuted),
                    ),
                    const SizedBox(height: 16),
                    Divider(color: c.line),
                    const SizedBox(height: 12),

                    // Smart Contract Verification Checklist
                    Text(
                      'Before financing',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c.inkFaint),
                    ),
                    const SizedBox(height: 8),

                    _checkItem(context,
                      label: 'Delivery confirmed',
                      detail: '$scannedCount/$totalCartons cartons (${(deliveryRatio * 100).toInt()}%)',
                      isPassed: isDeliveryConfirmed,
                    ),
                    _checkItem(context,
                      label: 'Dispute window closed',
                      detail: disputeWindowClosed ? 'Window closed · No objections filed' : 'Counting down',
                      isPassed: disputeWindowClosed,
                    ),
                    _checkItem(context,
                      label: 'Not already financed',
                      detail: 'No prior advance',
                      isPassed: true,
                    ),

                    const SizedBox(height: 20),

                    // Pricing breakdown based on tier
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
                          _statItem(context, 'Tier', state.creditHistory?.tier.label ?? 'BUILDING', c.brand),
                          _statItem(context, 'Advance', '80.0%', c.ink),
                          _statItem(context, 'Fee', '8.8%', c.pending),
                          _statItem(context, 'You receive', LaMPFormatters.formatBDT(182400 * 0.8), c.verified),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Execution button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _executeSmartContractAdvance(state),
                        icon: const Icon(Icons.flash_on),
                        label: Text(
                          'Finance ${LaMPFormatters.formatBDT(145920)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _activeBank == Msp.meghnaMSP ? c.brand : c.pending,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
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

  void _executeSmartContractAdvance(LaMPState state) async {
    final res = await state.financeReceivable(state.demoTokenId, _activeBank);
    setState(() {
      if (res.ok) {
        _isSuccessBanner = true;
        _executionBanner =
            'SMART CONTRACT FINANCING EXECUTED: Advance of ${LaMPFormatters.formatBDT(145920)} committed on block #${res.tx.blockNumber} by ${_activeBank.shortName}!';
      } else {
        _isSuccessBanner = false;
        _executionBanner = 'CHAINCODE REFUSAL: ${res.error} (Recorded in block #${res.tx.blockNumber} for audit)';
      }
    });
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
                      bands: SeedData.meghnaCurve.bands,
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

  Widget _buildPortfolioTab(BuildContext context, LaMPState state) {
    final c = context.lamp;
    return SingleChildScrollView(
      padding: lumaScrollPadding(context, top: Gap.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Portfolio',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.ink)),
                SizedBox(height: 8),
                Text('Exposure across financed receivables.',
                    style: TextStyle(fontSize: 12, color: c.inkMuted)),
                SizedBox(height: 20),
                Text('৳ 45,00,000 across 18 pharmacies',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.brand)),
                Text('Historical Default Rate: 0.0%',
                    style: TextStyle(fontSize: 12, color: c.verified)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
