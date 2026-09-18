import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_theme.dart';
import '../../core/constants/palette.dart';
import '../../core/constants/formatters.dart';
import '../../core/models/domain_models.dart';
import '../../core/state/lamp_state.dart';
import '../../core/world/seed.dart';
import '../../widgets/demo_director_sheet.dart';
import '../../widgets/ledger_inspector_sheet.dart';
import '../../widgets/lifecycle_rail.dart';
import '../../widgets/private_seal.dart';
import '../../widgets/ui/lamp_ui.dart';
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
    // Built below the Theme so `context.lamp` resolves to this seat's palette.
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
        appBar: AppBar(
          backgroundColor: c.surface,
          elevation: 1,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: c.ink),
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
                      'Manufacturer',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.ink),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.brand.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'SHOMOTA',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: c.brand),
                    ),
                  ),
                ],
              ),
              Text(
                'Shomota · Bogura Depot',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: c.inkFaint),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Ledger Inspector',
              icon: Icon(Icons.account_tree_outlined, color: c.verified),
              onPressed: () => LedgerInspectorSheet.show(context),
            ),
            IconButton(
              tooltip: 'Demo Director',
              icon: Icon(Icons.movie_filter_outlined, color: c.brand),
              onPressed: () => DemoDirectorSheet.show(context),
            ),
            const SizedBox(width: 6),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: c.brand,
            unselectedLabelColor: c.inkFaint,
            indicatorColor: c.brand,
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
    );
  }

  Widget _buildReceivablesTab(BuildContext context, LaMPState state, Delivery? delivery) {
    final c = context.lamp;
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
                  final card1 = _buildMetricCard(context,
                    'Total Receivables',
                    LaMPFormatters.formatBDT(182400),
                    '1 active consignment',
                    c.brand,
                  );
                  final card2 = _buildMetricCard(context,
                    'Delivery Ratio',
                    delivery != null
                        ? '${((delivery.cartons.where((c) => c.scannedAt != null).length / delivery.cartons.length) * 100).toInt()}%'
                        : '0%',
                    'Target: ≥90% for SCF',
                    c.verified,
                  );
                  final card3 = _buildMetricCard(context,
                    'Financing Status',
                    delivery?.status == DeliveryStatus.completed ? 'ELIGIBLE' : 'IN TRANSIT',
                    'Meghna Bank matching',
                    c.pending,
                  );

                  if (constraints.maxWidth < 600) {
                    return Column(
                      children: [
                        // Full width, like the pair beneath it. Alone in a
                        // Column it sized to its own content and floated in
                        // the middle of the screen, which read as a mistake
                        // next to two cards that fill the row.
                        SizedBox(width: double.infinity, child: card1),
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
                  color: c.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Active Receivable Tokens on Ledger',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.ink),
                        ),
                        Text(
                          'Consortium Channel: lamp-channel',
                          style: TextStyle(fontSize: 10, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, color: c.inkFaint),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Demo Token Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: c.lineStrong),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Id and amount share the row; the status chip goes
                          // below. All three abreast overflowed by 121.
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  state.demoInvoiceId,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
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
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.brand),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LampChip(
                            label: delivery?.status.id ?? 'CREATED',
                            tone: LampTone.verified,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Rahman Medical Hall · Bogura Sadar',
                            style: TextStyle(fontSize: 12, color: c.inkMuted),
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
                          // Both halves flex. Unreflowed, these two ran
                          // straight into each other — "RCV-00235Terms: 45
                          // days" — because spaceBetween distributes slack it
                          // does not have and clips nothing.
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'Token ${state.demoTokenId}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: LaMPType.mono,
                                    fontFamilyFallback: LaMPType.fallback,
                                    color: c.inkFaint,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  '45 days · ${delivery?.cartons.length ?? 25} cartons',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: c.inkFaint,
                                  ),
                                ),
                              ),
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

  Widget _buildMetricCard(BuildContext context, String label, String value, String sub, Color color) {
    final c = context.lamp;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: c.inkFaint)),
          const SizedBox(height: 4),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: c.inkFaint)),
        ],
      ),
    );
  }

  Widget _buildTrackingTab(BuildContext context, LaMPState state, Delivery? delivery) {
    final c = context.lamp;
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
                  color: c.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Consignment Tracking: ${delivery.invoiceId}',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.ink)),
                        Text('MPO: Kamrul Hasan',
                            style: TextStyle(fontSize: 12, color: c.inkFaint)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: c.line,
                        valueColor: AlwaysStoppedAnimation<Color>(c.brand),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$scanned of $total cartons confirmed on-chain',
                            style: TextStyle(fontSize: 11, color: c.inkMuted)),
                        Text('${(ratio * 100).toInt()}%',
                            style: TextStyle(fontSize: 11, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, fontWeight: FontWeight.bold, color: c.brand)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: c.line),
                    const SizedBox(height: 10),

                    // Private Data Collection Demo
                    Text('Private Data Collection (invoiceLineItems)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.ink)),
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
                    Text('On-Chain vs Off-Chain Split (Whitepaper §4.4)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.inkFaint)),
                    const SizedBox(height: 8),
                    _splitRow(context, 'On-Chain Token State', delivery.status.id, isChain: true),
                    _splitRow(context, 'Carton Hash Set (25 hashes)', 'Committed in Block', isChain: true),
                    _splitRow(context, 'Physical GPS & Courier Location', 'Bogura Sadar Road (Off-chain)', isChain: false),
                    _splitRow(context, 'Digital Signature Image', delivery.signatureRef ?? 'Pending (Off-chain)', isChain: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _splitRow(BuildContext context, String label, String value, {required bool isChain}) {
    final c = context.lamp;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(isChain ? Icons.link : Icons.cloud_outlined, size: 14, color: isChain ? c.verified : c.inkFaint),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 11, color: c.inkMuted)),
            ],
          ),
          Text(value, style: TextStyle(fontSize: 11, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, color: isChain ? c.verified : c.inkFaint)),
        ],
      ),
    );
  }

  Widget _buildMintTab(BuildContext context, LaMPState state) {
    final c = context.lamp;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mint New Receivable Token',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.ink)),
                Text('Enforces multi-MSP endorsement quorum AND(Mfr, OR(Banks)) upon creation',
                    style: TextStyle(fontSize: 12, color: c.inkMuted)),
                const SizedBox(height: 16),
                Divider(color: c.line),
                const SizedBox(height: 14),

                // Buyer Selection
                Text('BUYER PHARMACY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c.inkFaint)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: c.lineStrong),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 4,
                    children: [
                      Text('Rahman Medical Hall (রহমান মেডিকেল হল)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.ink)),
                      Text('Bogura Sadar', style: TextStyle(fontSize: 12, color: c.inkFaint)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Products & Cartons
                Text('MEDICINE LINE ITEMS & CARTONS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c.inkFaint)),
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
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
                              Text('${prod.strength} · ৳${prod.unitPrice}/unit · ${prod.unitsPerCarton} units/ctn',
                                  style: TextStyle(fontSize: 11, color: c.inkFaint)),
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
                Divider(color: c.line),
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
                            SnackBar(
                              backgroundColor: c.verified,
                              content: Text('Receivable token minted on blockchain with 2-MSP endorsement!'),
                            ),
                          );
                          _tabController.animateTo(0);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: c.dispute,
                              content: Text(res.error ?? 'Minting failed'),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.token_outlined),
                    label: const Text('Mint Receivable Token to Consortium Ledger'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.brand,
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
