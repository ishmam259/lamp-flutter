import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_theme.dart';
import '../../core/constants/palette.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/formatters.dart';
import '../../core/models/domain_models.dart';
import '../../core/state/lamp_state.dart';
import '../../core/world/seed.dart';
import '../../widgets/demo_director_sheet.dart';
import '../../widgets/ledger_inspector_sheet.dart';
import '../../widgets/recourse_dial.dart';
import '../../widgets/ui/lamp_ui.dart';
import '../../widgets/lamp_mark.dart';
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
    final state = context.watch<LaMPState>();
    final delivery = state.getDelivery(state.demoTokenId);

    return Theme(
      data: LaMPTheme.of(context, LampWorld.portal),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF131B17),
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: LaMPColors.portalInk),
            onPressed: widget.onBackToLauncher,
            tooltip: 'All Personas',
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const LampMark(size: 20),
                  const SizedBox(width: 8),
                  // The seat switcher in `actions` already names the bank, and
                  // naming it here too left neither with room — the title, the
                  // MSP chip and the dropdown were overlapping each other.
                  // Expanded, not Flexible: loose fit lets the text keep its
                  // natural width and overflow by 13, where tight fit makes it
                  // take exactly what is left.
                  const Expanded(
                    child: Text(
                      'Financing',
                      maxLines: 1,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: LaMPColors.portalInk),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // The MSP chip lived here too, and between it, the title and
                  // the seat switcher there was no room left — Flexible gave
                  // the title zero width and it vanished entirely. The switcher
                  // names the bank; one identifier in the bar is enough.
                ],
              ),
              const Text(
                'Consortium endorser',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: LaMPColors.portalInk3),
              ),
            ],
          ),
          actions: [
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
              tooltip: 'Ledger Inspector',
              icon: const Icon(Icons.account_tree_outlined, color: LaMPColors.verified),
              onPressed: () => LedgerInspectorSheet.show(context),
            ),
            IconButton(
              tooltip: 'Demo Director',
              icon: const Icon(Icons.movie_filter_outlined, color: LaMPColors.brand),
              onPressed: () => DemoDirectorSheet.show(context),
            ),
            const SizedBox(width: 6),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: LaMPColors.brand,
            unselectedLabelColor: LaMPColors.portalInk3,
            indicatorColor: LaMPColors.brand,
            tabs: const [
              Tab(text: "Financing Opportunities"),
              Tab(text: "Rate Curve & Tiers"),
              Tab(text: "Portfolio Overview"),
            ],
          ),
        ),
        body: SafeArea(
          // Android draws its gesture bar over the bottom of the window.
          // Without this the last row of every list sits underneath it.
          // Top is already handled by the AppBar.
          top: false,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOpportunitiesTab(context, state, delivery),
              _buildRateCurveTab(context, state),
              _buildPortfolioTab(context, state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpportunitiesTab(BuildContext context, LaMPState state, Delivery? delivery) {
    final scannedCount = delivery?.cartons.where((c) => c.scannedAt != null).length ?? 0;
    final totalCartons = delivery?.cartons.length ?? 25;
    final deliveryRatio = totalCartons > 0 ? scannedCount / totalCartons : 0.0;
    final isDeliveryConfirmed = deliveryRatio >= 0.90;

    // Check dispute window
    final disputeWindowClosed = (delivery?.status == DeliveryStatus.completed);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
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
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _isSuccessBanner ? LaMPColors.verifiedSoft : LaMPColors.disputeSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _isSuccessBanner ? LaMPColors.verified : LaMPColors.dispute),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isSuccessBanner ? Icons.check_circle : Icons.warning_rounded,
                        color: _isSuccessBanner ? LaMPColors.verifiedDark : LaMPColors.dispute,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _executionBanner!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _isSuccessBanner ? LaMPColors.verifiedDark : LaMPColors.dispute,
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
                  color: const Color(0xFF131B17),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: LaMPColors.portalLine),
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
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: LaMPType.mono,
                              fontFamilyFallback: LaMPType.fallback,
                              color: LaMPColors.portalInk,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          LaMPFormatters.formatBDT(182400),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: LaMPColors.brand),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const LampChip(label: 'SCF eligible', tone: LampTone.verified),
                    const SizedBox(height: 6),
                    // "Buyer: X · Seller: Y · Z" was sixty-six characters
                    // restating a relationship the portal never varies.
                    const Text(
                      'Rahman Medical Hall · Bogura Sadar',
                      style: TextStyle(fontSize: 12, color: LaMPColors.portalInk2),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: LaMPColors.portalLine),
                    const SizedBox(height: 14),

                    // Smart Contract Verification Checklist
                    const Text(
                      'SMART CONTRACT FINANCING PREREQUISITES',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: LaMPColors.portalInk3),
                    ),
                    const SizedBox(height: 10),

                    _checkItem(
                      label: 'Delivery Confirmed (≥90% Scanned)',
                      detail: '$scannedCount/$totalCartons cartons (${(deliveryRatio * 100).toInt()}%)',
                      isPassed: isDeliveryConfirmed,
                    ),
                    _checkItem(
                      label: '24-Hour Dispute Window Closed',
                      detail: disputeWindowClosed ? 'Window closed · No objections filed' : 'Dispute window counting down',
                      isPassed: disputeWindowClosed,
                    ),
                    _checkItem(
                      label: 'Receivable Unencumbered & Unfinanced',
                      detail: 'No previous financing token recorded on ledger',
                      isPassed: true,
                    ),

                    const SizedBox(height: 20),

                    // Pricing breakdown based on tier
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C2722),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 10,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          _statItem('COUNTERPARTY TIER', state.creditHistory?.tier.label ?? 'BUILDING', LaMPColors.brand),
                          _statItem('ADVANCE RATE', '80.0%', LaMPColors.portalInk),
                          _statItem('DISCOUNT FEE', '8.8%', LaMPColors.pending),
                          _statItem('DISBURSED AMOUNT', LaMPFormatters.formatBDT(182400 * 0.8), LaMPColors.verified),
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
                          'Execute Smart Contract Advance as ${_activeBank.shortName}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _activeBank == Msp.meghnaMSP ? LaMPColors.brand : LaMPColors.pending,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
  Widget _checkItem({required String label, required String detail, required bool isPassed}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              isPassed ? Icons.check_circle : Icons.hourglass_empty,
              size: 16,
              color: isPassed ? LaMPColors.verified : LaMPColors.pending,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: LaMPColors.portalInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: LaMPColors.portalInk3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: LaMPColors.portalInk3)),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF131B17),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: LaMPColors.portalLine),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dynamic Rate Curve & Recourse Dial (Whitepaper §4.6)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: LaMPColors.portalInk)),
                    const SizedBox(height: 4),
                    const Text(
                      'As on-chain repayment history accumulates, loss exposure automatically shifts from manufacturer to bank.',
                      style: TextStyle(fontSize: 12, color: LaMPColors.portalInk2),
                    ),
                    const SizedBox(height: 16),
                    RecourseDial(
                      bands: SeedData.meghnaCurve.bands,
                      currentTier: state.creditHistory?.tier ?? RecourseTier.building,
                      isDark: true,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF131B17),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: LaMPColors.portalLine),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bank Portfolio Management',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: LaMPColors.portalInk)),
                SizedBox(height: 6),
                Text('Real-time exposure across all verified pharmacy supply chain receivables.',
                    style: TextStyle(fontSize: 12, color: LaMPColors.portalInk2)),
                SizedBox(height: 20),
                Text('Total Portfolio Size: ৳ 45,00,000 across 18 pharmacies',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: LaMPColors.brand)),
                Text('Historical Default Rate: 0.0%',
                    style: TextStyle(fontSize: 12, color: LaMPColors.verified)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
