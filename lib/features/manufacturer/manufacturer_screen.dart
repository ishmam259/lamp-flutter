import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_theme.dart';
import '../../core/constants/ledger_labels.dart';
import '../../core/constants/palette.dart';
import '../../core/design/luma_press.dart';
import '../../core/design/luma_toast.dart';
import '../../core/design/luma_frost.dart';
import '../../core/constants/formatters.dart';
import '../../core/models/domain_models.dart';
import '../../core/state/lamp_state.dart';
import '../../core/world/queries.dart';
import '../../core/world/seed.dart';
import '../../widgets/ledger_inspector_sheet.dart';
import '../../widgets/lifecycle_rail.dart';
import '../../widgets/private_seal.dart';
import '../../widgets/ui/lamp_ledger_ui.dart';
import '../../widgets/ui/lamp_ui.dart';
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
  const ManufacturerScreen({super.key});

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

    return Scaffold(
      extendBodyBehindAppBar: true,
      // One bar for all five seats — see `LumaAppBar`. This one used to set
      // `elevation: 1`, which gave it a drop shadow no other screen had; the
      // separation is now a hairline under glass, and the content scrolls
      // visibly beneath it.
      appBar: LumaAppBar(
        title: 'Manufacturer',
        subtitle: 'Shomota · Bogura Depot',
        actions: [
          LampBlockPip(onTap: () => LedgerInspectorSheet.show(context)),
          const LampSeatMenu(),
        ],
        // Colours come from `tabBarTheme` now; the three screens that had a
        // TabBar were each setting the same three by hand.
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Invoices'),
            Tab(text: 'Tracking'),
            Tab(text: 'New invoice'),
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
      padding: lumaScrollPadding(context, top: Gap.lg),
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
                          'Invoices',
                          style: LaMPType.head.copyWith(color: c.ink),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (views.isEmpty)
                      Text(
                        'No invoices yet.',
                        style: LaMPType.caption.copyWith(color: c.inkFaint),
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
      TokenState.financed => LampTone.verified,
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
                  style: LaMPType.monoBody.copyWith(color: c.ink),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                LaMPFormatters.formatBDT(token.declaredValue),
                style: LaMPType.monoBody.copyWith(color: c.ink),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LampChip(label: token.state.label, tone: tone),
          const SizedBox(height: 8),
          Text(
            '${view.pharmacy?.name ?? token.buyerDid} · '
            '${view.pharmacy?.territory ?? ''}',
            style: LaMPType.caption.copyWith(color: c.inkMuted),
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
                  'Due ${LaMPFormatters.formatDate(token.dueDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LaMPType.caption.copyWith(color: c.inkFaint),
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
                  style: LaMPType.caption.copyWith(color: c.inkFaint),
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
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: LaMPType.caption.copyWith(color: c.inkFaint)),
          const SizedBox(height: 4),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: LaMPType.figure.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: LaMPType.caption.copyWith(color: c.inkFaint)),
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
                style: LaMPType.caption.copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: 4),
              Text(
                'Every consignment on the book has been handed over.',
                textAlign: TextAlign.center,
                style: LaMPType.caption.copyWith(color: c.inkFaint),
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
                    // `spaceBetween` distributes what is left over and does
                    // nothing at all when there is none — these two ran 418
                    // pixels off a 360dp phone. The title takes what it needs
                    // and the officer's name gives way.
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tracking · ${delivery.invoiceId}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: LaMPType.head.copyWith(color: c.ink),
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        Flexible(
                          child: Text(
                            'Kamrul Hasan',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: LaMPType.caption.copyWith(color: c.inkFaint),
                          ),
                        ),
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
                      children: [
                        Expanded(
                          child: Text(
                            '$scanned of $total cartons delivered',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: LaMPType.caption.copyWith(color: c.inkMuted),
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        Text('${(ratio * 100).toInt()}%',
                            style: LaMPType.monoCaption.copyWith(fontWeight: FontWeight.w600, color: c.brand)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: c.line),
                    const SizedBox(height: 8),

                    Text('Line items · private to ${SeedData.manufacturer.name}',
                        style: LaMPType.caption.copyWith(fontWeight: FontWeight.w600, color: c.ink)),
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

                    LampKeyValue(label: 'Delivery', value: delivery.status.label),
                    LampKeyValue(
                      label: 'Pharmacist signature',
                      value: delivery.signatureRef == null ? 'Not yet' : 'Signed',
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

  Widget _buildMintTab(BuildContext context, LaMPState state) {
    final c = context.lamp;
    return SingleChildScrollView(
      padding: lumaScrollPadding(context, top: Gap.lg),
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
                Text('New invoice',
                    style: LaMPType.head.copyWith(color: c.ink)),
                Text('Issued to the pharmacy once a partner bank co-signs.',
                    style: LaMPType.caption.copyWith(color: c.inkMuted)),
                const SizedBox(height: 16),
                Divider(color: c.line),
                const SizedBox(height: 12),

                // Buyer Selection
                Text('BUYER PHARMACY', style: LaMPType.label.copyWith(color: c.inkFaint)),
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
                          style: LaMPType.caption.copyWith(fontWeight: FontWeight.w600, color: c.ink)),
                      Text('Bogura Sadar', style: LaMPType.caption.copyWith(color: c.inkFaint)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Products & Cartons
                Text('MEDICINES',
                    style: LaMPType.label.copyWith(color: c.inkFaint)),
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
                                  style: LaMPType.caption.copyWith(fontWeight: FontWeight.w600, color: c.ink)),
                              Text('${prod.strength} · ৳${prod.unitPrice}/unit · ${prod.unitsPerCarton} units/ctn',
                                  style: LaMPType.caption.copyWith(color: c.inkFaint)),
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
                                style: LaMPType.monoCaption.copyWith(fontWeight: FontWeight.w600)),
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
                  style: LaMPType.caption.copyWith(fontWeight: FontWeight.w600, color: c.ink),
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
                          // A mint is a block. Two beats and a pill, not a
                          // four-second slab across the foot of the screen.
                          LumaHaptics.commit();
                          LumaToast.show(
                            context,
                            'Invoice issued',
                            icon: Icons.receipt_long_outlined,
                            tone: LumaToastTone.verified,
                          );
                          _tabController.animateTo(0);
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
                    },
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Issue invoice'),
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
