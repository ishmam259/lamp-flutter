import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_theme.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/formatters.dart';
import '../../core/models/domain_models.dart';
import '../../core/state/lamp_state.dart';
import '../../core/world/seed.dart';
import '../../widgets/demo_director_sheet.dart';
import '../../widgets/ledger_inspector_sheet.dart';
import '../../widgets/lifecycle_rail.dart';
import '../../widgets/private_seal.dart';
import '../../widgets/lamp_mark.dart';
import '../../core/constants/typography.dart';

class ManufacturerScreen extends StatefulWidget {
  final VoidCallback onBackToLauncher;

  const ManufacturerScreen({super.key, required this.onBackToLauncher});

  @override
  State<ManufacturerScreen> createState() => _ManufacturerScreenState();
}

class _ManufacturerScreenState extends State<ManufacturerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Minting form state
  final Map<String, int> _selectedCartons = {
    'SHM-PARA-500': 10,
    'SHM-ESOM-20': 8,
    'SHM-METF-500': 7,
  };
  final int _termsDays = 45;

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
      data: LaMPTheme.portal(),
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
                  const Flexible(
                    child: Text(
                      'Manufacturer Portal',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: LaMPColors.portalInk),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: LaMPColors.brand.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'SHOMOTA',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: LaMPColors.brand),
                    ),
                  ),
                ],
              ),
              Text(
                'Bogura Regional Depot · MSP: ManufacturerMSP',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: LaMPColors.portalInk3),
              ),
            ],
          ),
          actions: [
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
              Tab(text: "Receivables & Pipeline"),
              Tab(text: "Delivery Tracking"),
              Tab(text: "Mint Invoice"),
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
              _buildReceivablesTab(context, state, delivery),
              _buildTrackingTab(context, state, delivery),
              _buildMintTab(context, state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceivablesTab(BuildContext context, LaMPState state, Delivery? delivery) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stat Row
              LayoutBuilder(
                builder: (context, constraints) {
                  final card1 = _buildMetricCard(
                    'Total Receivables',
                    LaMPFormatters.formatBDT(182400),
                    '1 active consignment',
                    LaMPColors.brand,
                  );
                  final card2 = _buildMetricCard(
                    'Delivery Ratio',
                    delivery != null
                        ? '${((delivery.cartons.where((c) => c.scannedAt != null).length / delivery.cartons.length) * 100).toInt()}%'
                        : '0%',
                    'Target: ≥90% for SCF',
                    LaMPColors.verified,
                  );
                  final card3 = _buildMetricCard(
                    'Financing Status',
                    delivery?.status == DeliveryStatus.completed ? 'ELIGIBLE' : 'IN TRANSIT',
                    'Meghna Bank matching',
                    LaMPColors.pending,
                  );

                  if (constraints.maxWidth < 600) {
                    return Column(
                      children: [
                        card1,
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: card2),
                            const SizedBox(width: 10),
                            Expanded(child: card3),
                          ],
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: card1),
                      const SizedBox(width: 12),
                      Expanded(child: card2),
                      const SizedBox(width: 12),
                      Expanded(child: card3),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Active Invoices Table
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF131B17),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: LaMPColors.portalLine),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 4,
                      children: const [
                        Text(
                          'Active Receivable Tokens on Ledger',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: LaMPColors.portalInk),
                        ),
                        Text(
                          'Consortium Channel: lamp-channel',
                          style: TextStyle(fontSize: 10, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, color: LaMPColors.portalInk3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Demo Token Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C2722),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: LaMPColors.portalLine2),
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
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback,
                                      color: LaMPColors.portalInk,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: LaMPColors.verified.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      delivery?.status.id ?? 'CREATED',
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: LaMPColors.verified),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                LaMPFormatters.formatBDT(182400),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: LaMPColors.brand),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Rahman Medical Hall (রহমান মেডিকেল হল) · Bogura Sadar',
                            style: TextStyle(fontSize: 12, color: LaMPColors.portalInk2),
                          ),
                          const SizedBox(height: 12),

                          LifecycleRail(
                            state: delivery?.status == DeliveryStatus.completed
                                ? TokenState.delivered
                                : (delivery?.status == DeliveryStatus.scanning
                                    ? TokenState.partiallyFulfilled
                                    : TokenState.created),
                          ),

                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Token ID: RCV-00235',
                                  style: TextStyle(fontSize: 11, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, color: LaMPColors.hashInk)),
                              Text('Terms: 45 days · 25 Cartons',
                                  style: const TextStyle(fontSize: 11, color: LaMPColors.portalInk3)),
                            ],
                          ),
                        ],
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

  Widget _buildMetricCard(String label, String value, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B17),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LaMPColors.portalLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: LaMPColors.portalInk3)),
          const SizedBox(height: 4),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: LaMPColors.portalInk3)),
        ],
      ),
    );
  }

  Widget _buildTrackingTab(BuildContext context, LaMPState state, Delivery? delivery) {
    if (delivery == null) return const SizedBox();

    final scanned = delivery.cartons.where((c) => c.scannedAt != null).length;
    final total = delivery.cartons.length;
    final ratio = total > 0 ? scanned / total : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
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
                        Text('Consignment Tracking: ${delivery.invoiceId}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: LaMPColors.portalInk)),
                        Text('MPO: Kamrul Hasan',
                            style: const TextStyle(fontSize: 12, color: LaMPColors.portalInk3)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: LaMPColors.portalLine,
                        valueColor: const AlwaysStoppedAnimation<Color>(LaMPColors.brand),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$scanned of $total cartons confirmed on-chain',
                            style: const TextStyle(fontSize: 11, color: LaMPColors.portalInk2)),
                        Text('${(ratio * 100).toInt()}%',
                            style: const TextStyle(fontSize: 11, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, fontWeight: FontWeight.bold, color: LaMPColors.brand)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: LaMPColors.portalLine),
                    const SizedBox(height: 10),

                    // Private Data Collection Demo
                    const Text('Private Data Collection (invoiceLineItems)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: LaMPColors.portalInk)),
                    const SizedBox(height: 8),
                    const PrivateSeal(
                      cleartext: 'Paracetamol 500mg (10 ctn) · Esomeprazole 20mg (8 ctn) · Metformin HCl (7 ctn)',
                      hash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
                      isVisible: true,
                      memberName: 'Shomota Pharma',
                      isDark: true,
                    ),
                    const SizedBox(height: 16),

                    // On-chain vs Off-chain split
                    const Text('On-Chain vs Off-Chain Split (Whitepaper §4.4)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: LaMPColors.portalInk3)),
                    const SizedBox(height: 8),
                    _splitRow('On-Chain Token State', delivery.status.id, isChain: true),
                    _splitRow('Carton Hash Set (25 hashes)', 'Committed in Block', isChain: true),
                    _splitRow('Physical GPS & Courier Location', 'Bogura Sadar Road (Off-chain)', isChain: false),
                    _splitRow('Digital Signature Image', delivery.signatureRef ?? 'Pending (Off-chain)', isChain: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _splitRow(String label, String value, {required bool isChain}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(isChain ? Icons.link : Icons.cloud_outlined, size: 14, color: isChain ? LaMPColors.verified : LaMPColors.hashInk),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 11, color: LaMPColors.portalInk2)),
            ],
          ),
          Text(value, style: TextStyle(fontSize: 11, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, color: isChain ? LaMPColors.verified : LaMPColors.portalInk3)),
        ],
      ),
    );
  }

  Widget _buildMintTab(BuildContext context, LaMPState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF131B17),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: LaMPColors.portalLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mint New Receivable Token',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: LaMPColors.portalInk)),
                const Text('Enforces multi-MSP endorsement quorum AND(Mfr, OR(Banks)) upon creation',
                    style: TextStyle(fontSize: 12, color: LaMPColors.portalInk2)),
                const SizedBox(height: 16),
                const Divider(color: LaMPColors.portalLine),
                const SizedBox(height: 14),

                // Buyer Selection
                const Text('BUYER PHARMACY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: LaMPColors.portalInk3)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2722),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: LaMPColors.portalLine2),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 4,
                    children: const [
                      Text('Rahman Medical Hall (রহমান মেডিকেল হল)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: LaMPColors.portalInk)),
                      Text('Bogura Sadar', style: TextStyle(fontSize: 12, color: LaMPColors.portalInk3)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Products & Cartons
                const Text('MEDICINE LINE ITEMS & CARTONS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: LaMPColors.portalInk3)),
                const SizedBox(height: 8),

                for (final prod in SeedData.products.take(3)) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(prod.name,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: LaMPColors.portalInk)),
                              Text('${prod.strength} · ৳${prod.unitPrice}/unit · ${prod.unitsPerCarton} units/ctn',
                                  style: const TextStyle(fontSize: 11, color: LaMPColors.portalInk3)),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 18),
                              onPressed: () {
                                setState(() {
                                  final cur = _selectedCartons[prod.sku] ?? 0;
                                  if (cur > 0) _selectedCartons[prod.sku] = cur - 1;
                                });
                              },
                            ),
                            Text('${_selectedCartons[prod.sku] ?? 0} ctn',
                                style: const TextStyle(fontSize: 13, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 18),
                              onPressed: () {
                                setState(() {
                                  _selectedCartons[prod.sku] = (_selectedCartons[prod.sku] ?? 0) + 1;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(color: LaMPColors.portalLine),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final items = <LineItem>[];
                      for (final entry in _selectedCartons.entries) {
                        if (entry.value > 0) {
                          final prod = SeedData.products.firstWhere((p) => p.sku == entry.key);
                          items.add(LineItem(
                            sku: prod.sku,
                            name: prod.name,
                            strength: prod.strength,
                            quantity: entry.value * prod.unitsPerCarton,
                            cartons: entry.value,
                            unitPrice: prod.unitPrice,
                            lineValue: entry.value * prod.unitsPerCarton * prod.unitPrice,
                          ));
                        }
                      }

                      final res = await state.mintInvoice(
                        pharmacyDid: SeedData.pharmacies[0].did,
                        termsDays: _termsDays,
                        lineItems: items,
                      );

                      if (context.mounted) {
                        if (res.ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: LaMPColors.verifiedDark,
                              content: Text('Receivable token minted on blockchain with 2-MSP endorsement!'),
                            ),
                          );
                          _tabController.animateTo(0);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: LaMPColors.dispute,
                              content: Text(res.error ?? 'Minting failed'),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.token_outlined),
                    label: const Text('Mint Receivable Token to Consortium Ledger'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LaMPColors.brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
