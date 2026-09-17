import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/formatters.dart';
import '../../core/models/domain_models.dart';
import '../../core/state/lamp_state.dart';
import '../../core/world/seed.dart';
import '../../widgets/demo_director_sheet.dart';
import '../../widgets/ledger_inspector_sheet.dart';
import '../../widgets/recourse_dial.dart';
import '../../widgets/lamp_mark.dart';

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
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: LaMPColors.portalGround,
        primaryColor: LaMPColors.brand,
        colorScheme: const ColorScheme.dark(
          primary: LaMPColors.brand,
          secondary: LaMPColors.verified,
        ),
      ),
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
                  Flexible(
                    child: Text(
                      _activeBank == Msp.meghnaMSP ? 'Meghna Commercial' : 'Padma Bank Ltd',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: LaMPColors.portalInk),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _activeBank == Msp.meghnaMSP
                          ? LaMPColors.brand.withValues(alpha: 0.3)
                          : LaMPColors.pending.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _activeBank.id,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _activeBank == Msp.meghnaMSP ? LaMPColors.brand : LaMPColors.pending,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                'Supply Chain Finance Division · Consortium Endorser',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: LaMPColors.portalInk3),
              ),
            ],
          ),
          actions: [
            // Toggle active bank seat (Meghna vs Padma)
            DropdownButtonHideUnderline(
              child: DropdownButton<Msp>(
                value: _activeBank,
                dropdownColor: const Color(0xFF1C2722),
                icon: const Icon(Icons.swap_horiz, color: Colors.white70),
                items: const [
                  DropdownMenuItem(
                    value: Msp.meghnaMSP,
                    child: Text('Meghna Bank', style: TextStyle(fontSize: 12, color: LaMPColors.portalInk)),
                  ),
                  DropdownMenuItem(
                    value: Msp.padmaMSP,
                    child: Text('Padma Bank', style: TextStyle(fontSize: 12, color: LaMPColors.portalInk)),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _activeBank = val);
                },
              ),
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
        body: TabBarView(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              state.demoInvoiceId,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                color: LaMPColors.portalInk,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: LaMPColors.brand.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('SCF ELIGIBLE',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: LaMPColors.brand)),
                            ),
                          ],
                        ),
                        Text(
                          LaMPFormatters.formatBDT(182400),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: LaMPColors.brand),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Buyer: Rahman Medical Hall · Seller: Shomota Pharma · Bogura Sadar',
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

  Widget _checkItem({required String label, required String detail, required bool isPassed}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isPassed ? Icons.check_circle : Icons.hourglass_empty,
            size: 16,
            color: isPassed ? LaMPColors.verified : LaMPColors.pending,
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: LaMPColors.portalInk)),
          const Spacer(),
          Text(detail, style: const TextStyle(fontSize: 11, color: LaMPColors.portalInk3)),
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
