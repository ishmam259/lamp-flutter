import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_theme.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/formatters.dart';
import '../../core/models/domain_models.dart';
import '../../core/state/lamp_state.dart';
import '../../core/world/seed.dart';
import '../../widgets/credit_ring.dart';
import '../../widgets/demo_director_sheet.dart';
import '../../widgets/ledger_inspector_sheet.dart';
import '../../widgets/lamp_mark.dart';
import '../../core/constants/typography.dart';

class PharmacyScreen extends StatefulWidget {
  final VoidCallback onBackToLauncher;

  const PharmacyScreen({super.key, required this.onBackToLauncher});

  @override
  State<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends State<PharmacyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPaymentMethod = 'bKash';
  bool _justUpgraded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LaMPState>();
    final pharmacy = SeedData.pharmacies[0];
    final credit = state.creditHistory;

    return Theme(
      data: LaMPTheme.field(),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: LaMPColors.fieldInk),
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
                      pharmacy.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: LaMPColors.fieldInk),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: LaMPColors.brandSoft,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      credit?.tier.label.toUpperCase() ?? 'BUILDING',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: LaMPColors.brand),
                    ),
                  ),
                ],
              ),
              Text(
                '${pharmacy.nameBn} · ${pharmacy.territory} · ${pharmacy.licenceNo}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: LaMPColors.fieldInk3),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Ledger Inspector',
              icon: const Icon(Icons.account_tree_outlined, color: LaMPColors.verifiedDark),
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
            unselectedLabelColor: LaMPColors.fieldInk3,
            indicatorColor: LaMPColors.brand,
            tabs: const [
              Tab(text: "Dashboard"),
              Tab(text: "Credit Ring"),
              Tab(text: "Pay Invoices"),
              Tab(text: "Disputes"),
            ],
          ),
        ),
        body: SafeArea(
          // Android draws its gesture bar over the bottom of the window.
          // Without this the last row of every list sits underneath it.
          // Top is already handled by the AppBar.
          top: false,
          child: credit == null
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDashboardTab(context, state, pharmacy, credit),
                    _buildCreditTab(context, credit),
                    _buildPayTab(context, state, credit),
                    _buildDisputeTab(context, state),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDashboardTab(BuildContext context, LaMPState state, Pharmacy pharmacy, CreditHistory credit) {
    final demoDelivery = state.getDelivery(state.demoTokenId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tier upgrade celebration banner if just occurred
              if (_justUpgraded)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEBFBF4), Colors.white],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: LaMPColors.verified, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: LaMPColors.verified,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.upgrade, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TIER UPGRADE UNLOCKED!',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: LaMPColors.verifiedDark),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '8th cycle completed. Rahman Medical Hall has advanced to ESTABLISHED tier (85% advance rate, reduced fees).',
                              style: TextStyle(fontSize: 12, color: LaMPColors.fieldInk2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Credit Status Overview Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LaMPColors.fieldLine),
                ),
                child: Row(
                  children: [
                    CreditRing(
                      cycles: credit.cycles,
                      tier: credit.tier,
                      size: 110,
                      strokeWidth: 8,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Credit Level: ', style: TextStyle(fontSize: 12, color: LaMPColors.fieldInk3)),
                              Text(credit.tier.label,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: LaMPColors.brand)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${credit.onTimeCount} on-time · ${credit.lateCount} late · 0 defaults',
                            style: const TextStyle(fontSize: 11, color: LaMPColors.fieldInk2),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            credit.tier.blurb,
                            style: const TextStyle(fontSize: 11, color: LaMPColors.fieldInk3, height: 1.3),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _tabController.animateTo(1),
                            child: const Text('View Full History & Cycles →',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: LaMPColors.brand)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Upcoming Payment Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LaMPColors.fieldLine),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Upcoming Medicine Payment',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: LaMPColors.fieldInk),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: LaMPColors.pendingSoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('PAYABLE',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: LaMPColors.pending)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('AMOUNT DUE', style: TextStyle(fontSize: 10, color: LaMPColors.fieldInk3)),
                            Text(LaMPFormatters.formatBDT(182400),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('INVOICE ID', style: TextStyle(fontSize: 10, color: LaMPColors.fieldInk3)),
                            Text(state.demoInvoiceId,
                                style: const TextStyle(fontSize: 14, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _tabController.animateTo(2),
                        icon: const Icon(Icons.payment, size: 16),
                        label: const Text('Pay Invoice via bKash / Nagad'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LaMPColors.brand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Recent Deliveries
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LaMPColors.fieldLine),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Recent Consignments',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: LaMPColors.fieldInk)),
                    const SizedBox(height: 10),
                    if (demoDelivery != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: LaMPColors.brandSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.local_shipping_outlined, color: LaMPColors.brand, size: 20),
                        ),
                        title: Text(demoDelivery.invoiceId,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback)),
                        subtitle: Text(
                          '${demoDelivery.cartons.length} cartons · Shomota Pharma',
                          style: const TextStyle(fontSize: 11, color: LaMPColors.fieldInk3),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: demoDelivery.status == DeliveryStatus.completed
                                ? LaMPColors.verifiedSoft
                                : LaMPColors.pendingSoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            demoDelivery.status.id,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: demoDelivery.status == DeliveryStatus.completed
                                  ? LaMPColors.verifiedDark
                                  : LaMPColors.pending,
                            ),
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

  Widget _buildCreditTab(BuildContext context, CreditHistory credit) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LaMPColors.fieldLine),
                ),
                child: Column(
                  children: [
                    CreditRing(
                      cycles: credit.cycles,
                      tier: credit.tier,
                      size: 160,
                      strokeWidth: 12,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${credit.tier.label.toUpperCase()} TIER',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: LaMPColors.brand),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${credit.cycles.length} completed credit cycles on-chain',
                      style: const TextStyle(fontSize: 12, color: LaMPColors.fieldInk2),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: LaMPColors.fieldLine),
                    const SizedBox(height: 12),
                    const Text(
                      'Every on-time settlement builds immutable credit history. No bank or manufacturer can alter or erase these records.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: LaMPColors.fieldInk3, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Cycle Breakdown List
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LaMPColors.fieldLine),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cycle History',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: LaMPColors.fieldInk)),
                    const SizedBox(height: 10),
                    for (final (i, c) in credit.cycles.indexed) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  c.onTime ? Icons.check_circle : Icons.error_outline,
                                  color: c.onTime ? LaMPColors.verified : LaMPColors.pending,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Cycle ${i + 1} (${c.invoiceId})',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(LaMPFormatters.formatBDT(c.value),
                                    style: const TextStyle(fontSize: 12, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: c.onTime ? LaMPColors.verifiedSoft : LaMPColors.pendingSoft,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    c.onTime ? 'ON TIME' : '${c.daysLate}d LATE',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: c.onTime ? LaMPColors.verifiedDark : LaMPColors.pending,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (i < credit.cycles.length - 1) const Divider(color: LaMPColors.fieldLine, height: 1),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPayTab(BuildContext context, LaMPState state, CreditHistory credit) {
    const amount = 182400.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LaMPColors.fieldLine),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Settle Consignment',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: LaMPColors.fieldInk)),
                    const Text('Paying on delivery completes cycle 8 and triggers recourse tier upgrade.',
                        style: TextStyle(fontSize: 12, color: LaMPColors.fieldInk2)),
                    const SizedBox(height: 16),
                    const Divider(color: LaMPColors.fieldLine, height: 1),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Invoice:', style: TextStyle(fontSize: 13, color: LaMPColors.fieldInk3)),
                        Text(state.demoInvoiceId,
                            style: const TextStyle(fontSize: 14, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Amount Payable:', style: TextStyle(fontSize: 13, color: LaMPColors.fieldInk3)),
                        Text(LaMPFormatters.formatBDT(amount),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: LaMPColors.brand)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    const Text('Select Payment Method',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: LaMPColors.fieldInk)),
                    const SizedBox(height: 10),

                    _paymentOption(
                      title: 'bKash Merchant Payment',
                      subtitle: 'Direct instant settlement via MFS wallet',
                      value: 'bKash',
                      color: LaMPColors.bKash,
                    ),
                    _paymentOption(
                      title: 'Nagad Business Pay',
                      subtitle: 'Postal network digital settlement',
                      value: 'Nagad',
                      color: LaMPColors.nagad,
                    ),
                    _paymentOption(
                      title: 'Bank EFT / RTGS Transfer',
                      subtitle: 'Corporate bank account clearance',
                      value: 'Bank Transfer',
                      color: LaMPColors.brand,
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _executePayment(state, amount),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedPaymentMethod == 'bKash'
                              ? LaMPColors.bKash
                              : (_selectedPaymentMethod == 'Nagad' ? LaMPColors.nagad : LaMPColors.brand),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          'Confirm & Pay ${LaMPFormatters.formatBDT(amount)} via $_selectedPaymentMethod',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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

  Widget _paymentOption({
    required String title,
    required String subtitle,
    required String value,
    required Color color,
  }) {
    final isSelected = _selectedPaymentMethod == value;

    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethod = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : LaMPColors.fieldLine,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? color : Colors.black26, width: 2),
                color: isSelected ? color : Colors.transparent,
              ),
              child: isSelected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? color : LaMPColors.fieldInk)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: LaMPColors.fieldInk3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _executePayment(LaMPState state, double amount) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Processing $_selectedPaymentMethod Payment'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Submitting settlement to Hyperledger consortium ledger...'),
          ],
        ),
      ),
    );

    final res = await state.settleReceivable(state.demoTokenId, amount, _selectedPaymentMethod);

    if (mounted) {
      Navigator.pop(context); // close progress dialog
      if (res.ok) {
        setState(() {
          _justUpgraded = true;
        });
        _tabController.animateTo(0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: LaMPColors.verifiedDark,
            content: Text('Settlement recorded on blockchain! Tier upgraded to ESTABLISHED.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: LaMPColors.dispute,
            content: Text(res.error ?? 'Settlement rejected'),
          ),
        );
      }
    }
  }

  Widget _buildDisputeTab(BuildContext context, LaMPState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: LaMPColors.fieldLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dispute Centre',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: LaMPColors.fieldInk)),
                const Text('Raise objections before the 24-hour dispute window closes',
                    style: TextStyle(fontSize: 12, color: LaMPColors.fieldInk2)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    await state.raiseDispute(state.demoTokenId, 'Damaged seals reported by Rahman Medical Hall');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Dispute raised. Token reopened to DISPUTED.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.report_problem),
                  label: const Text('Raise Delivery Dispute'),
                  style: ElevatedButton.styleFrom(backgroundColor: LaMPColors.dispute, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
