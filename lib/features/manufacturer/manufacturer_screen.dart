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

/// The manufacturer's desk: the book of invoices, what is on the road, and
/// issuing a new one.
///
/// A desk seat, so the book is a table rather than a stack of cards — one
/// line per invoice, opened in place for its lifecycle and ledger receipt.
class ManufacturerScreen extends StatefulWidget {
  const ManufacturerScreen({super.key});

  @override
  State<ManufacturerScreen> createState() => _ManufacturerScreenState();
}

class _ManufacturerScreenState extends State<ManufacturerScreen> {
  /// Invoices, Tracking, New invoice.
  int _tab = 0;

  /// The invoice row opened in the book. Null opens none.
  String? _openTokenId;
  bool _openedDefault = false;

  // New-invoice form.
  String _pharmacyDid = SeedData.pharmacies[0].did;
  final Map<String, int> _cartons = {
    'SHM-PARA-500': 10,
    'SHM-ESOM-20': 8,
    'SHM-METF-500': 7,
  };

  /// Credit period on the invoice being issued.
  int _termsDays = 45;
  bool _issuing = false;

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
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: LumaAppBar(
        title: Msp.manufacturerMSP.shortName,
        subtitle: 'Receivables · ${SeedData.manufacturer.depot}',
        actions: [
          LampBlockPip(onTap: () => LedgerInspectorSheet.show(context)),
          const LampSeatMenu(),
        ],
      ),
      body: Builder(
        builder: (context) => IndexedStack(
          index: _tab,
          children: [
            _invoicesTab(context, state),
            _trackingTab(context, state),
            _newInvoiceTab(context, state),
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
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Invoices',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_shipping_outlined),
              selectedIcon: Icon(Icons.local_shipping),
              label: 'Tracking',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: 'New invoice',
            ),
          ],
        ),
      ),
    );
  }

  /* ---------------------------------------------------------------------- */
  /* Invoices                                                                */
  /* ---------------------------------------------------------------------- */

  Widget _invoicesTab(BuildContext context, LaMPState state) {
    final c = context.lamp;
    final views = state.tokenViews;
    if (!_openedDefault && views.isNotEmpty) {
      _openTokenId = views.first.tokenId;
      _openedDefault = true;
    }

    return ListView(
      padding: lumaScrollPadding(context, top: Gap.lg),
      children: [
        _summary(context, state, views),
        const SizedBox(height: Gap.xl),
        LampEyebrow('Invoices', trailing: '${views.length}'),
        const SizedBox(height: Gap.md),
        if (views.isEmpty)
          const LampEmpty(
            icon: Icons.receipt_long_outlined,
            title: 'No invoices yet',
            message: 'Issue one from New invoice.',
          )
        else
          LampCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < views.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, color: c.line),
                  _invoiceRow(context, state, views[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  /// Outstanding, and how it splits by where each invoice is.
  Widget _summary(BuildContext context, LaMPState state, List<TokenView> views) {
    final c = context.lamp;
    final open = views.where((v) => v.token.isOpen).toList();
    final outstanding = open.fold<double>(0, (s, v) => s + v.token.declaredValue);
    final advanced = views.fold<double>(
      0,
      (s, v) => s + (v.token.financing?.advancedAmount ?? 0),
    );
    final ready = views.where((v) => v.token.isFinanceable(state.now)).length;

    int count(bool Function(TokenState s) test) =>
        open.where((v) => test(_tokenStateFor(v))).length;
    final segments = [
      ('delivered', count((s) => s == TokenState.delivered), c.verified),
      ('financed', count((s) => s == TokenState.financed), c.inkMuted),
      ('being delivered', count((s) => s == TokenState.partiallyFulfilled), c.pending),
      ('issued', count((s) => s == TokenState.created), c.lineStrong),
      ('disputed', count((s) => s == TokenState.disputed), c.dispute),
    ].where((s) => s.$2 > 0).toList();
    final total = segments.fold<int>(0, (s, e) => s + e.$2);

    return LampCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LampEyebrow('Outstanding'),
          const SizedBox(height: Gap.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              LaMPFormatters.formatBDT(outstanding),
              style: LaMPType.displayFigure.copyWith(color: c.ink),
            ),
          ),
          Text(
            '${open.length} open ${open.length == 1 ? 'invoice' : 'invoices'}',
            style: LaMPType.caption.copyWith(color: c.inkFaint),
          ),
          if (total > 0) ...[
            const SizedBox(height: Gap.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(LaMPRadius.pill),
              child: Row(
                children: [
                  for (int i = 0; i < segments.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      flex: segments[i].$2,
                      child: Container(height: 8, color: segments[i].$3),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Gap.sm),
            Wrap(
              spacing: Gap.md,
              runSpacing: Gap.xs,
              children: [
                for (final s in segments)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: s.$3, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: Gap.xs),
                      Text(
                        '${s.$1} ${s.$2}',
                        style: LaMPType.caption.copyWith(color: c.inkMuted),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          Divider(height: Gap.xl, thickness: 1, color: c.line),
          Row(
            children: [
              Expanded(
                child: _figure(context, 'Advanced by banks',
                    LaMPFormatters.formatBDTCompact(advanced)),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: _figure(context, 'Ready to finance', '$ready'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _figure(BuildContext context, String label, String value) {
    final c = context.lamp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: LaMPType.caption.copyWith(color: c.inkFaint)),
        const SizedBox(height: Gap.xs),
        Text(value, style: LaMPType.monoBody.copyWith(color: c.ink)),
      ],
    );
  }

  /// Where an invoice stands, as a phrase and a state.
  (LampState, String) _standing(LaMPState state, TokenView view) {
    final token = view.token;
    return switch (_tokenStateFor(view)) {
      TokenState.created => (LampState.pending, 'Issued · not yet delivered'),
      TokenState.partiallyFulfilled => (
          LampState.pending,
          'Being delivered · ${token.scanned} of ${token.declaredCartons} cartons'
        ),
      TokenState.delivered => token.isFinanceable(state.now)
          ? (LampState.confirmed, 'Delivered · ready to finance')
          : (LampState.confirmed, 'Delivered · dispute window open'),
      TokenState.financed => (
          LampState.confirmed,
          'Financed by ${token.financing?.bankMsp.shortName ?? 'a bank'}'
        ),
      TokenState.settled => (LampState.confirmed, 'Paid'),
      TokenState.disputed => (LampState.refused, 'Disputed'),
      TokenState.defaulted => (LampState.refused, 'Overdue'),
    };
  }

  Widget _invoiceRow(BuildContext context, LaMPState state, TokenView view) {
    final c = context.lamp;
    final token = view.token;
    final open = _openTokenId == view.tokenId;
    final standing = _standing(state, view);
    final tx = state.lastTxFor(token.tokenId);

    return InkWell(
      onTap: () => setState(() => _openTokenId = open ? null : view.tokenId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
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
                  style: LaMPType.monoBody.copyWith(color: c.ink),
                ),
              ],
            ),
            const SizedBox(height: Gap.xs),
            Row(
              children: [
                LampStateDot(standing.$1),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    '${standing.$2} · ${view.pharmacy?.name ?? 'Pharmacy'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LaMPType.caption.copyWith(color: c.inkMuted),
                  ),
                ),
              ],
            ),
            if (open) ...[
              const SizedBox(height: Gap.lg),
              LifecycleRail(
                state: _tokenStateFor(view),
                isFinanced: token.financing != null,
              ),
              const SizedBox(height: Gap.lg),
              LampKeyValue(
                label: 'Pharmacy',
                value: '${view.pharmacy?.name ?? '—'} · ${view.pharmacy?.territory ?? ''}',
              ),
              LampKeyValue(
                label: 'Cartons',
                value: '${token.scanned} of ${token.declaredCartons} delivered',
              ),
              LampKeyValue(
                label: 'Due',
                value: '${LaMPFormatters.formatDate(token.dueDate)} · '
                    '${token.termsDays} days',
              ),
              if (tx != null)
                LampReceiptFooter(
                  tx: tx,
                  onOpen: () => LedgerInspectorSheet.show(context),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /* ---------------------------------------------------------------------- */
  /* Tracking                                                                */
  /* ---------------------------------------------------------------------- */

  /// Every consignment still on the road, carton by carton.
  Widget _trackingTab(BuildContext context, LaMPState state) {
    final inTransit = state.tokenViews
        .where((v) => v.delivery != null && !v.token.isFullyScanned)
        .toList();

    return ListView(
      padding: lumaScrollPadding(context, top: Gap.lg),
      children: [
        if (inTransit.isEmpty)
          const LampEmpty(
            icon: Icons.local_shipping_outlined,
            title: 'Nothing on the road',
            message: 'Every consignment has been handed over.',
          )
        else ...[
          LampEyebrow(
            'On the road',
            trailing: '${inTransit.length} '
                '${inTransit.length == 1 ? 'consignment' : 'consignments'}',
          ),
          const SizedBox(height: Gap.md),
          for (final v in inTransit) ...[
            _consignmentCard(context, v),
            const SizedBox(height: Gap.md),
          ],
        ],
      ],
    );
  }

  Widget _consignmentCard(BuildContext context, TokenView view) {
    final c = context.lamp;
    final delivery = view.delivery!;
    final lineItems = view.invoice?.lineItems ?? const <LineItem>[];
    final scanned = view.token.scanned;
    final total = view.token.declaredCartons;
    final refused = delivery.cartons
        .where((x) => x.rejected == true && x.scannedAt == null)
        .length;
    String officer = 'Delivery officer';
    for (final m in SeedData.mpos) {
      if (m.id == delivery.mpoId) officer = m.name;
    }

    return LampCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  view.token.invoiceId,
                  style: LaMPType.monoBody.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              LampStateChip(LampState.pending, delivery.status.label),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Text(
            '${view.pharmacy?.name ?? 'Pharmacy'} · $officer',
            style: LaMPType.caption.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: Gap.lg),
          LampTickBar.of([
            for (final x in delivery.cartons)
              if (x.rejected == true && x.scannedAt == null)
                LampState.refused
              else if (x.scannedAt != null)
                LampState.confirmed
              else
                null,
          ]),
          const SizedBox(height: Gap.sm),
          Text(
            refused > 0
                ? '$scanned of $total cartons delivered · $refused refused'
                : '$scanned of $total cartons delivered',
            style: LaMPType.monoCaption.copyWith(color: c.inkMuted),
          ),
          Divider(height: Gap.xl, thickness: 1, color: c.line),
          Text(
            'Line items · private to ${SeedData.manufacturer.name}',
            style: LaMPType.caption.copyWith(color: c.inkFaint),
          ),
          const SizedBox(height: Gap.sm),
          // The real line items and the digest the ledger holds for them.
          PrivateSeal(
            cleartext: lineItems.isEmpty
                ? 'No line items on this consignment'
                : lineItems
                    .map((l) => '${l.name} ${l.strength} (${l.cartons} cartons)')
                    .join(' · '),
            hash: view.token.lineItemsHash,
            isVisible: true,
            memberName: 'you',
          ),
          const SizedBox(height: Gap.md),
          LampKeyValue(
            label: 'Pharmacist signature',
            value: delivery.signatureRef == null ? 'Not yet' : 'Signed',
          ),
        ],
      ),
    );
  }

  /* ---------------------------------------------------------------------- */
  /* New invoice                                                             */
  /* ---------------------------------------------------------------------- */

  Widget _newInvoiceTab(BuildContext context, LaMPState state) {
    final c = context.lamp;
    final products = SeedData.products;
    final cartons = _cartons.values.fold<int>(0, (s, n) => s + n);
    final value = products.fold<double>(
      0,
      (s, p) => s + (_cartons[p.sku] ?? 0) * p.unitsPerCarton * p.unitPrice,
    );

    return ListView(
      padding: lumaScrollPadding(context, top: Gap.lg),
      children: [
        const LampEyebrow('Pharmacy'),
        const SizedBox(height: Gap.md),
        DropdownButtonFormField<String>(
          initialValue: _pharmacyDid,
          isExpanded: true,
          items: [
            for (final p in SeedData.pharmacies)
              DropdownMenuItem(
                value: p.did,
                child: Text(
                  '${p.name} · ${p.territory}',
                  overflow: TextOverflow.ellipsis,
                  style: LaMPType.body.copyWith(color: c.ink),
                ),
              ),
          ],
          onChanged: (v) => setState(() => _pharmacyDid = v ?? _pharmacyDid),
        ),
        const SizedBox(height: Gap.xl),
        LampEyebrow('Medicines', trailing: '$cartons cartons'),
        const SizedBox(height: Gap.md),
        LampCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (int i = 0; i < products.length; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 1, color: c.line),
                _productRow(context, products[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: Gap.xl),
        const LampEyebrow('Credit period'),
        const SizedBox(height: Gap.md),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 30, label: Text('30 days')),
            ButtonSegment(value: 45, label: Text('45 days')),
            ButtonSegment(value: 60, label: Text('60 days')),
          ],
          selected: {_termsDays},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _termsDays = s.first),
        ),
        const SizedBox(height: Gap.xl),
        LampCard(
          child: Column(
            children: [
              LampKeyValue(label: 'Cartons', value: '$cartons', mono: true),
              LampKeyValue(
                label: 'Invoice total',
                value: LaMPFormatters.formatBDT(value),
                mono: true,
              ),
              LampKeyValue(
                label: 'Due',
                value: LaMPFormatters.formatDate(
                    state.now + _termsDays * SeedData.day),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.lg),
        ElevatedButton.icon(
          onPressed: cartons == 0 || _issuing ? null : () => _issue(context, state),
          icon: const Icon(Icons.receipt_long_outlined, size: IconSize.md),
          label: Text(cartons == 0
              ? 'Add at least one carton'
              : 'Issue invoice · ${LaMPFormatters.formatBDT(value)}'),
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
        const SizedBox(height: Gap.sm),
        Text(
          'Issued to the pharmacy once a partner bank co-signs.',
          textAlign: TextAlign.center,
          style: LaMPType.caption.copyWith(color: c.inkFaint),
        ),
      ],
    );
  }

  Widget _productRow(BuildContext context, Product p) {
    final c = context.lamp;
    final n = _cartons[p.sku] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(left: Gap.lg, right: Gap.xs),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${p.name} ${p.strength}',
                      style: LaMPType.sub.copyWith(color: n > 0 ? c.ink : c.inkMuted)),
                  Text(
                    '${p.unitsPerCarton} per carton · ৳${p.unitPrice} each',
                    style: LaMPType.caption.copyWith(color: c.inkFaint),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'One fewer',
            onPressed: n == 0 ? null : () => setState(() => _cartons[p.sku] = n - 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$n',
              textAlign: TextAlign.center,
              style: LaMPType.monoBody.copyWith(color: n > 0 ? c.ink : c.inkFaint),
            ),
          ),
          IconButton(
            tooltip: 'One more',
            onPressed: () => setState(() => _cartons[p.sku] = n + 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }

  Future<void> _issue(BuildContext context, LaMPState state) async {
    final items = <LineItem>[
      for (final p in SeedData.products)
        if ((_cartons[p.sku] ?? 0) > 0)
          LineItem(
            sku: p.sku,
            name: p.name,
            strength: p.strength,
            quantity: _cartons[p.sku]! * p.unitsPerCarton,
            cartons: _cartons[p.sku]!,
            unitPrice: p.unitPrice,
            lineValue: _cartons[p.sku]! * p.unitsPerCarton * p.unitPrice,
          ),
    ];

    setState(() => _issuing = true);
    final res = await state.mintInvoice(
      pharmacyDid: _pharmacyDid,
      termsDays: _termsDays,
      lineItems: items,
    );
    if (!mounted) return;
    setState(() => _issuing = false);

    if (res.ok) {
      LumaHaptics.commit();
      LumaToast.show(
        this.context,
        'Invoice issued',
        icon: Icons.receipt_long_outlined,
        tone: LumaToastTone.verified,
      );
      setState(() {
        _tab = 0;
        _openTokenId = state.tokenViews.isEmpty ? null : state.tokenViews.first.tokenId;
      });
    } else {
      LumaHaptics.reject();
      LumaToast.show(
        this.context,
        LedgerLabels.reason(res.error),
        icon: Icons.error_outline,
        tone: LumaToastTone.dispute,
      );
    }
  }
}
