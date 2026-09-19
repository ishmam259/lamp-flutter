import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_theme.dart';
import '../../core/constants/palette.dart';
import '../../core/constants/formatters.dart';
import '../../core/models/domain_models.dart';
import '../../core/state/lamp_state.dart';
import '../../core/world/queries.dart';
import '../../core/world/seed.dart';
import '../../widgets/demo_director_sheet.dart';
import '../../widgets/ledger_inspector_sheet.dart';
import '../../widgets/lifecycle_rail.dart';
import '../../widgets/private_seal.dart';
import '../../widgets/ui/lamp_ui.dart';
import '../../widgets/lamp_mark.dart';
import '../../core/constants/typography.dart';

/// The lifecycle state the rail should draw for one receivable.
///
/// The chaincode is authoritative. The off-chain delivery row only gets a say
/// where the ledger has nothing more specific to offer — mid-scan, or handed
/// over but not yet countersigned.
TokenState _tokenStateFor(TokenView view) {
  final token = view.token;
  switch (token.state) {
    case TokenState.settled:
    case TokenState.financed:
    case TokenState.disputed:
    case TokenState.defaulted:
    case TokenState.delivered:
      return token.state;
    case TokenState.partiallyFulfilled:
    case TokenState.created:
      break;
  }
  final status = view.delivery?.status;
  if (status == DeliveryStatus.completed ||
      status == DeliveryStatus.awaitingConfirmation) {
    return TokenState.delivered;
  }
  if (status == DeliveryStatus.scanning) return TokenState.partiallyFulfilled;
  return token.state;
}

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
  /// Credit period on the invoice being minted.
  ///
  /// Was `final`, on a form whose every other field had a stepper — so the
  /// one commercial term that varies between counterparties could not be set.
  int _termsDays = 45;

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
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
            const SizedBox(width: 8),
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
              _buildReceivablesTab(context, state),
              _buildTrackingTab(context, state),
              _buildMintTab(context, state),
            ],
          ),
        ),
    );
  }

  /// The book: every receivable this manufacturer has on the ledger.
  ///
  /// Drew one hard-coded consignment before, with the literal counterparty
  /// "Rahman Medical Hall" and the literal term "45 days" beneath it, so a
  /// minted invoice showed up nowhere at all.
  Widget _buildReceivablesTab(BuildContext context, LaMPState state) {
    final c = context.lamp;
    final views = state.tokenViews;

    final outstanding = views
        .where((v) => v.token.isOpen)
        .fold<double>(0.0, (sum, TokenView v) => sum + v.token.declaredValue);
    final advanced = views.fold<double>(
      0.0,
      (sum, TokenView v) => sum + (v.token.financing?.advancedAmount ?? 0.0),
    );
    final awaiting = views
        .where((v) =>
            v.token.state == TokenState.created ||
            v.token.state == TokenState.partiallyFulfilled)
        .length;
    final financeable =
        views.where((v) => v.token.isFinanceable(state.now)).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final card1 = _buildMetricCard(
                    context,
                    'Outstanding',
                    LaMPFormatters.formatBDTCompact(outstanding),
                    '${views.where((v) => v.token.isOpen).length} open',
                    c.brand,
                  );
                  final card2 = _buildMetricCard(
                    context,
                    'Advanced by banks',
                    LaMPFormatters.formatBDTCompact(advanced),
                    'against the book',
                    c.verified,
                  );
                  final card3 = _buildMetricCard(
                    context,
                    'Awaiting delivery',
                    '$awaiting',
                    '$financeable financeable now',
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
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: card2),
                            const SizedBox(width: 8),
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
                          'On the ledger',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.ink),
                        ),
                        Text(
                          'lamp-channel',
                          style: TextStyle(fontSize: 10, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, color: c.inkFaint),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (views.isEmpty)
                      Text(
                        'No receivables on the ledger yet.',
                        style: TextStyle(fontSize: 12, color: c.inkFaint),
                      )
                    else
                      for (final view in views) ...[
                        _receivableCard(context, view),
                        const SizedBox(height: 8),
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

  Widget _receivableCard(BuildContext context, TokenView view) {
    final c = context.lamp;
    final token = view.token;

    final tone = switch (token.state) {
      TokenState.settled => LampTone.verified,
      TokenState.financed => LampTone.chain,
      TokenState.delivered => LampTone.verified,
      TokenState.disputed => LampTone.dispute,
      TokenState.defaulted => LampTone.dispute,
      _ => LampTone.neutral,
    };

    return Container(
      padding: const EdgeInsets.all(12),
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
                  token.invoiceId,
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
                LaMPFormatters.formatBDT(token.declaredValue),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.brand),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LampChip(label: token.state.label, tone: tone),
          const SizedBox(height: 8),
          Text(
            '${view.pharmacy?.name ?? token.buyerDid} · '
            '${view.pharmacy?.territory ?? ''}',
            style: TextStyle(fontSize: 12, color: c.inkMuted),
          ),
          const SizedBox(height: 12),

          LifecycleRail(
            state: _tokenStateFor(view),
            isFinanced: token.financing != null,
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
                  'Token ${token.tokenId}',
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
                  '${token.termsDays} days · '
                  '${token.scanned}/${token.declaredCartons} cartons',
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
    );
  }

  Widget _buildMetricCard(BuildContext context, String label, String value, String sub, Color color) {
    final c = context.lamp;
    return Container(
      padding: const EdgeInsets.all(12),
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

  /// Carton-level progress on the consignment currently in transit.
  ///
  /// Returned a bare `SizedBox` when there was no delivery — a blank tab with
  /// nothing on it and no explanation.
  Widget _buildTrackingTab(BuildContext context, LaMPState state) {
    final c = context.lamp;

    // The one still moving: not yet fully scanned, nearest first.
    final inTransit = state.tokenViews
        .where((v) => v.delivery != null && !v.token.isFullyScanned)
        .toList();
    final view = inTransit.isNotEmpty ? inTransit.first : null;

    if (view == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_shipping_outlined, size: 40, color: c.inkFaint),
              const SizedBox(height: 12),
              Text(
                'Nothing in transit.',
                style: TextStyle(fontSize: 13, color: c.inkMuted),
              ),
              const SizedBox(height: 4),
              Text(
                'Every consignment on the book has been handed over.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: c.inkFaint),
              ),
            ],
          ),
        ),
      );
    }

    final delivery = view.delivery!;
    final lineItems = view.invoice?.lineItems ?? const <LineItem>[];
    // Scanned count off the ledger, not off the off-chain rows.
    final scanned = view.token.scanned;
    final total = view.token.declaredCartons;
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
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 8),

                    // Private Data Collection Demo
                    Text('Private Data Collection (invoiceLineItems)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.ink)),
                    const SizedBox(height: 8),
                    // The real line items and the real digest the chaincode
                    // put on the channel. This was a literal product list that
                    // ignored the consignment, over a literal hash that was
                    // the SHA-256 of the empty string.
                    PrivateSeal(
                      cleartext: lineItems.isEmpty
                          ? 'No line items on this consignment'
                          : lineItems
                              .map((l) =>
                                  '${l.name} ${l.strength} (${l.cartons} ctn)')
                              .join(' · '),
                      hash: view.token.lineItemsHash,
                      isVisible: true,
                      memberName: SeedData.manufacturer.name,
                    ),
                    const SizedBox(height: 16),

                    // On-chain vs Off-chain split
                    Text('On-Chain vs Off-Chain Split (Whitepaper §4.4)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.inkFaint)),
                    const SizedBox(height: 8),
                    _splitRow(context, 'On-Chain Token State', delivery.status.id, isChain: true),
                    _splitRow(context, 'Carton Hash Set (${view.token.declaredCartons} hashes)', 'Committed in Block', isChain: true),
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
              const SizedBox(width: 8),
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
                Text('Needs a bank co-signature',
                    style: TextStyle(fontSize: 12, color: c.inkMuted)),
                const SizedBox(height: 16),
                Divider(color: c.line),
                const SizedBox(height: 12),

                // Buyer Selection
                Text('BUYER PHARMACY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c.inkFaint)),
                const SizedBox(height: 8),
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
                    padding: const EdgeInsets.symmetric(vertical: 8),
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

                // The credit period. Every other field on this form had a
                // control; this one was a `final` field fixed at 45 days.
                Text(
                  'Credit period',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final days in const [30, 45, 60])
                      ChoiceChip(
                        label: Text('$days days'),
                        selected: _termsDays == days,
                        onSelected: (_) => setState(() => _termsDays = days),
                      ),
                  ],
                ),

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
                              content: Text('Receivable minted'),
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
                      foregroundColor: c.onBrand,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
