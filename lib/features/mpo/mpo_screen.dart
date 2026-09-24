import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/chain/contract.dart';
import '../../core/chain/crypto.dart';
import '../../core/constants/app_mode.dart';
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
import '../../widgets/carton_code_view.dart';
import '../../widgets/ui/lamp_ledger_ui.dart';
import '../../widgets/ui/lamp_skeleton.dart';
import '../../widgets/ui/lamp_ui.dart';
import '../../widgets/carton_scanner_sheet.dart';
import '../../widgets/data_matrix_view.dart';
import '../../widgets/ledger_inspector_sheet.dart';
import '../../widgets/signature_pad.dart';
import '../../core/constants/typography.dart';

/// The delivery officer's seat: today's round, the cartons at the door, the
/// pharmacist's signature, and returns.
///
/// Laid out against the redesign's MPO mockups (`docs/DESIGN_SYSTEM.md`):
/// one bar with the block pip, a bottom nav the thumb can reach, one stop
/// open at a time as a receipt of its last ledger write, and carton progress
/// as 25 ticks rather than a percentage — so the refused carton shows in its
/// own position.
class MpoScreen extends StatefulWidget {
  /// Whose round this is: the signed-in officer. Null opens the first
  /// officer in the seed, which is what tests and previews use.
  final String? mpoId;

  const MpoScreen({super.key, this.mpoId});

  @override
  State<MpoScreen> createState() => _MpoScreenState();
}

class _MpoScreenState extends State<MpoScreen> {
  /// A carton belonging to no consignment in this world.
  ///
  /// The scan cascade substitutes this at position 14, and the same payload is
  /// offered as a scannable code so the camera path can be refused too. It has
  /// to be one string: two literals that drifted apart would leave the camera
  /// demo quietly accepting what the tap demo refuses.
  static const String _misroutedGs1 =
      '(01)08901234001019(17)280824(10)BCH-FOREIGN(21)SN-9999';

  /// Route, Scan, Sign, Returns.
  int _tab = 0;
  bool _offlineMode = false;
  final List<String> _offlineQueue = [];
  bool _autoScanning = false;
  Timer? _autoTimer;
  bool _hasSignature = false;

  /// The stop the Scan, Sign and Returns tabs are working on.
  ///
  /// The screen used to read one hard-coded consignment, which is why a
  /// completed delivery stayed on the route with nothing behind it and a
  /// newly minted one appeared nowhere.
  String? _activeTokenId;

  /// The signed-in officer.
  Mpo get _me => SeedData.mpos.firstWhere(
        (m) => m.id == widget.mpoId,
        orElse: () => SeedData.mpos.first,
      );

  /// Today's remaining stops, nearest in sequence first.
  List<TokenView> _route(LaMPState state) => state.routeFor(_me.id);

  /// The selected stop, or the first one still outstanding.
  ///
  /// Falling back to the head of the route is what makes a signed-for delivery
  /// hand over to the next consignment instead of leaving the tabs pointed at
  /// something that is no longer on the round.
  TokenView? _activeStop(LaMPState state) {
    final route = _route(state);
    if (route.isEmpty) return null;
    for (final v in route) {
      if (v.tokenId == _activeTokenId) return v;
    }
    return route.first;
  }

  void _goTo(int tab) => setState(() => _tab = tab);

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Built below the Theme so `context.lamp` resolves to the field palette.
    return Theme(
      data: LaMPTheme.of(context, LampWorld.field),
      child: Builder(builder: _buildScaffold),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final state = context.watch<LaMPState>();
    final route = _route(state);
    final active = _activeStop(state);
    final c = context.lamp;

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: LumaAppBar(
        title: 'Delivery officer',
        subtitle: '${_me.name} · ${_me.territory}',
        actions: [
          // Offline, the pip gives way to what is waiting to be written —
          // the one fact about the ledger that is not on it yet.
          if (_offlineQueue.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
              child: Center(
                child: LampStateChip(
                  LampState.pending,
                  '${_offlineQueue.length} queued',
                ),
              ),
            )
          else
            LampBlockPip(
              onTap: () => LedgerInspectorSheet.show(context),
            ),
          const LampSeatMenu(),
        ],
      ),
      // No SafeArea: each tab reads the insets itself through
      // `lumaScrollPadding`, under a Builder so the bar's height is folded in.
      body: Builder(
        builder: (context) => !state.isInitialized
            ? const LampShimmer(
                child: Padding(
                  padding: EdgeInsets.all(Gap.lg),
                  child: Column(
                    children: [
                      LampSkeletonCard(lines: 2),
                      SizedBox(height: Gap.lg),
                      LampSkeletonCard(lines: 1),
                    ],
                  ),
                ),
              )
            : IndexedStack(
                index: _tab,
                children: [
                  _buildRouteTab(context, route, state),
                  active == null
                      ? _noStop(context, 'Nothing left to scan.')
                      : _buildScannerTab(context, active, state),
                  active == null
                      ? _noStop(context, 'Nothing left to sign for.')
                      : _buildConfirmTab(context, active, state),
                  active == null
                      ? _noStop(context, 'Nothing left to return.')
                      : _buildReturnsTab(context, active, state),
                ],
              ),
      ),
      bottomNavigationBar: LumaFrost(
        border: Border(top: BorderSide(color: c.line)),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _goTo,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.route_outlined),
              selectedIcon: Icon(Icons.route),
              label: 'Route',
            ),
            NavigationDestination(
              icon: Icon(Icons.qr_code_scanner),
              label: 'Scan',
            ),
            NavigationDestination(
              icon: Icon(Icons.draw_outlined),
              selectedIcon: Icon(Icons.draw),
              label: 'Sign',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_return_outlined),
              selectedIcon: Icon(Icons.assignment_return),
              label: 'Returns',
            ),
          ],
        ),
      ),
    );
  }

  /// What the working tabs show when the round is done.
  Widget _noStop(BuildContext context, String message) {
    return ListView(
      padding: lumaScrollPadding(context, top: Gap.lg),
      children: [
        LampEmpty(
          icon: Icons.check_circle_outline,
          title: message,
          message: 'Every consignment assigned to this device has been handed over.',
        ),
      ],
    );
  }

  /// Per-carton states for the tick bar, in manifest order.
  ///
  /// Drawn from the carton rows so a refusal sits where it happened; the
  /// counts beside the bar come off the ledger.
  List<LampState?> _ticks(Delivery? delivery) => [
        for (final carton in delivery?.cartons ?? const <Carton>[])
          if (carton.rejected == true && carton.scannedAt == null)
            LampState.refused
          else if (_offlineQueue.contains(carton.gs1))
            LampState.pending
          else if (carton.scannedAt != null)
            LampState.confirmed
          else
            null,
      ];

  int _refused(Delivery? delivery) => (delivery?.cartons ?? const <Carton>[])
      .where((c) => c.rejected == true && c.scannedAt == null)
      .length;

  /// Today's round.
  ///
  /// A stop leaves this list once the ledger holds every carton and the
  /// pharmacy has signed — the same two conditions as `app/mpo/page.tsx:28-36`.
  /// One stop is open at a time; the rest wait under it, a tap away.
  Widget _buildRouteTab(
    BuildContext context,
    List<TokenView> route,
    LaMPState state,
  ) {
    final c = context.lamp;
    final active = _activeStop(state);

    if (active == null) {
      return ListView(
        padding: lumaScrollPadding(context, top: Gap.lg),
        children: const [
          LampEmpty(
            icon: Icons.check_circle_outline,
            title: 'Round complete',
            message: 'No deliveries assigned today.',
          ),
        ],
      );
    }

    int positionOf(TokenView v) =>
        route.indexWhere((r) => r.tokenId == v.tokenId) + 1;
    final position = positionOf(active);
    final others = [
      for (final v in route)
        if (v.tokenId != active.tokenId) v,
    ];
    final lines = active.invoice?.lineItems ?? const <LineItem>[];

    return ListView(
      padding: lumaScrollPadding(context, top: Gap.lg),
      children: [
        _stopCard(context, active, state, position: position, total: route.length),
        if (others.isNotEmpty) ...[
          const SizedBox(height: Gap.xl),
          LampEyebrow(
            position == 1 ? 'Next' : 'Also on the round',
            trailing: '${others.length} ${others.length == 1 ? 'stop' : 'stops'}',
          ),
          const SizedBox(height: Gap.md),
          for (final v in others) ...[
            _nextStopRow(context, v, positionOf(v)),
            const SizedBox(height: Gap.sm),
          ],
        ],
        const SizedBox(height: Gap.xl),
        LampEyebrow(
          'Manifest',
          trailing: '${lines.length} ${lines.length == 1 ? 'line' : 'lines'}',
        ),
        const SizedBox(height: Gap.md),
        // Read off the invoice. These were three literal rows naming
        // Paracetamol, Esomeprazole and Metformin whatever the consignment
        // actually held.
        if (lines.isEmpty)
          Text(
            'No line items recorded for this consignment.',
            style: LaMPType.caption.copyWith(color: c.inkFaint),
          )
        else
          LampCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < lines.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, color: c.line),
                  _manifestRow(context, lines[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  /// The open stop, as a receipt of the last thing the ledger recorded
  /// against it.
  Widget _stopCard(
    BuildContext context,
    TokenView view,
    LaMPState state, {
    required int position,
    required int total,
  }) {
    final c = context.lamp;
    final token = view.token;
    final pharmacy = view.pharmacy;
    final scanned = token.scanned;
    final declared = token.declaredCartons;
    final complete = token.isFullyScanned;
    final refused = _refused(view.delivery);
    final left = (declared - scanned).clamp(0, declared);

    final status = switch (view.delivery?.status) {
      DeliveryStatus.completed => (LampState.confirmed, 'Delivered'),
      DeliveryStatus.awaitingConfirmation => (LampState.pending, 'Awaiting signature'),
      DeliveryStatus.scanning => (LampState.pending, 'Scanning'),
      DeliveryStatus.disputed => (LampState.refused, 'Disputed'),
      _ => (LampState.pending, 'Pending'),
    };

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A Wrap, not a Row: "Awaiting signature" beside the stop counter
        // runs off a 360dp phone, and a status the officer needs to read is
        // not something to ellipsise.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            LampEyebrow('Stop $position of $total'),
            LampStateChip(status.$1, status.$2),
          ],
        ),
        const SizedBox(height: Gap.md),
        Text(
          pharmacy?.name ?? token.buyerDid,
          style: LaMPType.title.copyWith(color: c.ink),
        ),
        if (pharmacy != null)
          Text(
            '${pharmacy.nameBn} · ${pharmacy.address}',
            style: LaMPType.caption.copyWith(color: c.inkMuted),
          ),
        Divider(height: Gap.xl, thickness: 1, color: c.line),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: _figure(context, 'Invoice', Text(token.invoiceId)),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              flex: 3,
              child: _figure(
                context,
                'Cartons',
                Text.rich(TextSpan(children: [
                  TextSpan(text: '$scanned'),
                  TextSpan(
                    text: '/$declared',
                    style: LaMPType.monoBody.copyWith(color: c.inkFaint),
                  ),
                ])),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              flex: 5,
              child: _figure(
                context,
                'Value ৳',
                Text(LaMPFormatters.formatBDTPlain(token.declaredValue)),
                end: true,
              ),
            ),
          ],
        ),
        Divider(height: Gap.xl, thickness: 1, color: c.line),
        LampTickBar.of(_ticks(view.delivery)),
        const SizedBox(height: Gap.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                refused > 0
                    ? '$scanned verified · $refused refused'
                    : '$scanned verified',
                style: LaMPType.monoCaption.copyWith(color: c.inkMuted),
              ),
            ),
            Text(
              '${(LaMPContract.confirmationThreshold * 100).round()}% to finance',
              style: LaMPType.monoCaption.copyWith(color: c.inkFaint),
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        ElevatedButton.icon(
          onPressed: () {
            setState(() => _activeTokenId = token.tokenId);
            _goTo(complete ? 2 : 1);
          },
          icon: Icon(
            complete ? Icons.draw_outlined : Icons.qr_code_scanner,
            size: IconSize.md,
          ),
          label: complete
              ? const Text('Hand over and sign')
              : Text.rich(TextSpan(children: [
                  TextSpan(text: scanned == 0 ? 'Scan cartons' : 'Continue scanning'),
                  TextSpan(
                    text: '  $left left',
                    style: LaMPType.monoCaption.copyWith(
                      color: c.onBrand.withValues(alpha: 0.7),
                    ),
                  ),
                ])),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );

    final tx = state.lastTxFor(token.tokenId);
    if (tx == null) return LampCard(child: body);
    return LampReceiptCard(
      tx: tx,
      onOpen: () => LedgerInspectorSheet.show(context),
      child: body,
    );
  }

  /// An uppercase label over a mono figure, scaled down rather than clipped
  /// when the column is narrow.
  Widget _figure(BuildContext context, String label, Widget value, {bool end = false}) {
    final c = context.lamp;
    return Column(
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        LampEyebrow(label),
        const SizedBox(height: Gap.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: end ? Alignment.centerRight : Alignment.centerLeft,
          child: DefaultTextStyle(
            style: LaMPType.monoBody.copyWith(
              color: c.ink,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            child: value,
          ),
        ),
      ],
    );
  }

  /// A stop further down the round. Tapping opens it above.
  Widget _nextStopRow(BuildContext context, TokenView view, int position) {
    final c = context.lamp;
    final pharmacy = view.pharmacy;
    return LampCard(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      onTap: () => setState(() => _activeTokenId = view.tokenId),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(LaMPRadius.control),
            ),
            child: Text(
              '$position',
              style: LaMPType.monoCaption.copyWith(color: c.inkMuted),
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pharmacy?.name ?? view.token.buyerDid,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LaMPType.sub.copyWith(color: c.ink),
                ),
                if (pharmacy != null)
                  Text(
                    pharmacy.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LaMPType.caption.copyWith(color: c.inkFaint),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Gap.md),
          Text(
            '${view.token.declaredCartons} cartons',
            style: LaMPType.monoCaption.copyWith(color: c.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _manifestRow(BuildContext context, LineItem line) {
    final c = context.lamp;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${line.name} ${line.strength}',
                  style: LaMPType.sub.copyWith(color: c.ink),
                ),
                Text(
                  line.sku,
                  style: LaMPType.monoCaption.copyWith(color: c.inkFaint),
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${line.cartons} ${line.cartons == 1 ? 'carton' : 'cartons'}',
                style: LaMPType.monoCaption.copyWith(
                  color: c.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${LaMPFormatters.formatBDTPlain(line.quantity)} units',
                style: LaMPType.caption.copyWith(color: c.inkFaint),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScannerTab(BuildContext context, TokenView view, LaMPState state) {
    final c = context.lamp;
    final delivery = view.delivery!;
    // Counts come off the token: the ledger is what decides whether this
    // consignment has been delivered. The ticks come off the carton rows,
    // so each one sits in its own position.
    final scannedCount = view.token.scanned;
    final totalCartons = view.token.declaredCartons;
    final refused = _refused(delivery);
    final queued = _offlineQueue.length;
    final toGo = (totalCartons - scannedCount - refused - queued).clamp(0, totalCartons);

    return ListView(
      padding: lumaScrollPadding(context, top: Gap.lg),
      children: [
        LampCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const LampEyebrow('Cartons checked'),
                        const SizedBox(height: Gap.xs),
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(text: '$scannedCount'),
                            TextSpan(
                              text: ' / $totalCartons',
                              style: LaMPType.figure.copyWith(color: c.inkFaint),
                            ),
                          ]),
                          style: LaMPType.figure.copyWith(color: c.ink),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _offlineMode ? 'OFFLINE' : 'ONLINE',
                    style: LaMPType.label.copyWith(
                      color: _offlineMode ? c.pending : c.inkFaint,
                    ),
                  ),
                  Switch(
                    value: _offlineMode,
                    activeThumbColor: c.pending,
                    onChanged: (val) {
                      setState(() => _offlineMode = val);
                      if (!val && _offlineQueue.isNotEmpty) {
                        _drainQueue(state, delivery.tokenId);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: Gap.md),
              LampTickBar.of(_ticks(delivery)),
              const SizedBox(height: Gap.sm),
              Wrap(
                spacing: Gap.md,
                children: [
                  Text('$scannedCount verified',
                      style: LaMPType.monoCaption.copyWith(color: c.verified)),
                  if (refused > 0)
                    Text('$refused refused',
                        style: LaMPType.monoCaption.copyWith(color: c.dispute)),
                  if (queued > 0)
                    Text('$queued queued',
                        style: LaMPType.monoCaption.copyWith(color: c.pending)),
                  Text('$toGo to go',
                      style: LaMPType.monoCaption.copyWith(color: c.inkFaint)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.lg),

        if (cameraScanningSupported) ...[
          ElevatedButton.icon(
            onPressed: () => _openCameraScanner(state, delivery),
            icon: const Icon(Icons.qr_code_scanner, size: IconSize.md),
            label: const Text('Scan with camera'),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: Gap.sm),
        ],
        Row(
          children: [
            Expanded(
              child: cameraScanningSupported
                  ? OutlinedButton.icon(
                      onPressed: () => _scanNextCarton(state, delivery),
                      icon: const Icon(Icons.touch_app_outlined, size: IconSize.md),
                      label: const Text('Scan next'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    )
                  : ElevatedButton.icon(
                      onPressed: () => _scanNextCarton(state, delivery),
                      icon: const Icon(Icons.touch_app_outlined, size: IconSize.md),
                      label: const Text('Scan next'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    ),
            ),
            if (kDemoTools) ...[
            const SizedBox(width: Gap.sm),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _toggleAutoScan(state, delivery),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: _autoScanning ? c.dispute : null,
                  side: _autoScanning ? BorderSide(color: c.dispute) : null,
                ),
                child: Text(_autoScanning ? 'Stop' : 'Scan all'),
              ),
            ),
            ],
          ],
        ),
        // Present a carton from no consignment to a second device, so the
        // camera can be refused by the chaincode on camera. Testing only.
        if (kDemoTools)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _showMisroutedCode(context),
            icon: const Icon(Icons.report_gmailerrorred_outlined, size: IconSize.sm),
            label: const Text('Show a misrouted carton code'),
            style: TextButton.styleFrom(
              foregroundColor: c.dispute,
              padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
            ),
          ),
        ),
        if (!cameraScanningSupported)
          Text(
            'Camera scanning runs on Android and iOS.',
            style: LaMPType.caption.copyWith(color: c.inkFaint),
          ),
        const SizedBox(height: Gap.xl),

        LampEyebrow('Cartons', trailing: '${delivery.cartons.length} total'),
        const SizedBox(height: Gap.md),
        for (int i = 0; i < delivery.cartons.length; i++) ...[
          _cartonRow(context, view, delivery.cartons[i], i),
          const SizedBox(height: Gap.sm),
        ],

        if (scannedCount >= totalCartons) ...[
          const SizedBox(height: Gap.md),
          ElevatedButton.icon(
            onPressed: () => _goTo(2),
            icon: const Icon(Icons.draw_outlined, size: IconSize.md),
            label: const Text('Hand over and sign'),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ],
      ],
    );
  }

  /// One carton. A refused one says why, on its own row, where it happened —
  /// the one moment the demo exists to show is not a banner at the top.
  Widget _cartonRow(BuildContext context, TokenView view, Carton carton, int i) {
    final c = context.lamp;
    final refused = carton.rejected == true && carton.scannedAt == null;
    final queued = _offlineQueue.contains(carton.gs1);
    final scanned = carton.scannedAt != null && !queued;
    // Carton 14 on a full-size consignment. A short one, like the 5-carton
    // hero, has no index 13, so the marker goes midway instead of vanishing.
    final cartonCount = view.delivery?.cartons.length ?? 0;
    final isPlant = i == (cartonCount > 13 ? 13 : cartonCount ~/ 2);

    final Widget trailing;
    if (refused) {
      trailing = const LampStateChip(LampState.refused, 'Refused');
    } else if (queued) {
      trailing = const LampStateChip(LampState.pending, 'Queued');
    } else if (scanned) {
      trailing = Icon(Icons.check_circle, color: c.verified, size: IconSize.md);
    } else if (isPlant && kDemoTools) {
      trailing = const LampStateChip(LampState.refused, 'Test carton');
    } else {
      trailing = Icon(Icons.radio_button_unchecked, color: c.lineStrong, size: IconSize.md);
    }

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(LaMPRadius.card),
        border: Border.all(color: refused ? c.dispute : c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Tapping enlarges the carton's code into something a second
              // device can actually read.
              InkWell(
                onTap: () => _showCartonCode(context, carton),
                borderRadius: BorderRadius.circular(LaMPRadius.control),
                child: DataMatrixView(text: carton.gs1, size: 40),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      carton.cartonId,
                      style: LaMPType.monoCaption.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      refused
                          ? 'Not on this invoice'
                          : '${carton.sku} · ${carton.batch}',
                      style: refused
                          ? LaMPType.caption.copyWith(color: c.dispute)
                          : LaMPType.monoCaption.copyWith(color: c.inkFaint),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              trailing,
            ],
          ),
          if (refused) ...[
            Divider(height: Gap.xl, thickness: 1, color: c.line),
            Text(
              "This carton belongs to a different consignment, so it wasn't "
              'accepted for ${view.token.invoiceId}. Set it aside and report '
              'it under Returns.',
              style: LaMPType.caption.copyWith(color: c.inkMuted),
            ),
          ],
        ],
      ),
    );
  }

  /// Open the live camera and submit whatever it decodes.
  ///
  /// The payload goes to the chaincode untouched — the sheet never checks it
  /// against the manifest first — so a carton from another invoice is refused
  /// by `recordPoD`'s own membership test, on camera, for real.
  Future<void> _openCameraScanner(LaMPState state, Delivery delivery) async {
    _autoTimer?.cancel();
    if (_autoScanning) setState(() => _autoScanning = false);

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => CartonScannerSheet(
          invoiceId: delivery.invoiceId,
          scannedCount: delivery.cartons.where((c) => c.scannedAt != null).length,
          totalCartons: delivery.cartons.length,
          onPayload: (payload) async {
            final res = await state.scanCarton(
              delivery.tokenId,
              payload,
              _me.deviceId,
            );

            if (!res.ok) {
              return CartonScanResult(
                accepted: false,
                message: LedgerLabels.reason(res.error),
                matched: SeedData.foreignCarton(),
              );
            }

            final hash = LaMPCrypto.sha256Hex(payload);
            final match = delivery.cartons.where((c) => c.hash == hash);
            final carton = match.isEmpty ? null : match.first;
            final label = carton?.cartonId ?? 'Carton';
            final done =
                delivery.cartons.where((c) => c.scannedAt != null).length;

            return CartonScanResult(
              accepted: true,
              message: '$label recorded — $done of ${delivery.cartons.length}',
              matched: carton,
            );
          },
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  /// Display the misrouted carton, for scanning from another device.
  void _showMisroutedCode(BuildContext context) {
    final c = context.lamp;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(
          'Test carton',
          style: LaMPType.head,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'A carton from a different consignment. Scan it with the '
                "camera to check that the app won't accept it.",
                style: LaMPType.caption.copyWith(color: c.inkMuted, height: 1.4),
              ),
              const SizedBox(height: 12),
              const CartonCodeView(gs1: _misroutedGs1, size: 200),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Show a carton's code large enough to be scanned off the screen.
  ///
  /// Without printed labels this is the only way to exercise the camera path,
  /// and it is also how the planted foreign carton gets presented to a second
  /// device during the demo.
  void _showCartonCode(BuildContext context, Carton carton) {
    final c = context.lamp;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(
          carton.cartonId,
          style: LaMPType.sub.copyWith(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: CartonCodeView(gs1: carton.gs1, size: 200),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// The next carton still to be handed over on this consignment.
  ///
  /// A carton sitting in the offline queue counts as taken. Without that the
  /// cascade re-queued the same carton every tick, because a queued scan is
  /// deliberately not marked on the row until the chaincode accepts the batch.
  int _nextCartonIndex(Delivery delivery) {
    for (int i = 0; i < delivery.cartons.length; i++) {
      final carton = delivery.cartons[i];
      if (carton.scannedAt != null) continue;
      if (_offlineQueue.contains(carton.gs1)) continue;
      return i;
    }
    return -1;
  }

  void _scanNextCarton(LaMPState state, Delivery delivery) async {
    final unscannedIndex = _nextCartonIndex(delivery);
    if (unscannedIndex == -1) {
      _autoTimer?.cancel();
      if (mounted) setState(() => _autoScanning = false);
      return;
    }

    final targetCarton = delivery.cartons[unscannedIndex];

    // Check if this is the planted foreign carton (#14 -> index 13)
    // On the real demo, Carton 14 is presented with a foreign payload
    // Testing only: a release build scans the carton the officer is holding.
    if (kDemoTools && unscannedIndex == 13 && targetCarton.rejected != true) {
      // Send foreign barcode to trigger genuine chaincode refusal!
      final res =
          await state.scanCarton(delivery.tokenId, _misroutedGs1, _me.deviceId);
      // The refused payload hashes to nothing in this manifest, so
      // `scanCarton` has no row to mark. Flag the carton the officer was
      // holding through LaMPState rather than mutating it from inside this
      // widget's setState, which left every other seat unaware of it.
      state.markCartonRejected(
        delivery.tokenId,
        targetCarton.cartonId,
        res.error ?? 'Carton does not belong to this invoice.',
      );
      if (!mounted) return;
      // The refusal itself is drawn on the carton's row, in position. The
      // toast is only the moment it happened.
      LumaHaptics.reject();
      LumaToast.show(
        context,
        "${targetCarton.cartonId} isn't on this invoice",
        icon: Icons.block,
        tone: LumaToastTone.dispute,
      );
      return;
    }

    if (_offlineMode) {
      // Queued, not recorded. The row is deliberately left unscanned: the
      // chaincode has not seen this carton yet, and `drainScanQueue` only
      // marks rows once it accepts the batch. Marking it here made a refused
      // batch leave every queued carton reading as verified.
      _offlineQueue.add(targetCarton.gs1);
      if (!mounted) return;
      setState(() {
        targetCarton.scannedAt = state.now;
      });
      // Optimistic by construction: the carton was marked scanned above,
      // before anything was written anywhere. The toast is the receipt for a
      // decision the interface has already taken.
      LumaHaptics.select();
      LumaToast.show(
        context,
        'Queued · ${_offlineQueue.length} offline',
        icon: Icons.cloud_off_outlined,
        tone: LumaToastTone.pending,
        duration: const Duration(milliseconds: 1200),
      );
    } else {
      await state.scanCarton(delivery.tokenId, targetCarton.gs1, _me.deviceId);
    }
  }

  void _toggleAutoScan(LaMPState state, Delivery delivery) {
    if (_autoScanning) {
      _autoTimer?.cancel();
      setState(() => _autoScanning = false);
    } else {
      setState(() => _autoScanning = true);
      _autoTimer = Timer.periodic(const Duration(milliseconds: 650), (t) {
        // Re-resolve the stop each tick. The timer used to close over the
        // delivery captured when the tab was built, so a stop change — or a
        // world reset — left it cascading through a detached object.
        final active = _activeStop(state);
        final current = active?.delivery;
        if (!mounted || current == null || current.tokenId != delivery.tokenId) {
          t.cancel();
          if (mounted) setState(() => _autoScanning = false);
          return;
        }
        if (_nextCartonIndex(current) == -1) {
          t.cancel();
          setState(() => _autoScanning = false);
        } else {
          _scanNextCarton(state, current);
        }
      });
    }
  }

  void _drainQueue(LaMPState state, String tokenId) async {
    if (_offlineQueue.isEmpty) return;
    final count = _offlineQueue.length;
    await state.drainScanQueue(tokenId, List.from(_offlineQueue), _me.deviceId);
    setState(() {
      _offlineQueue.clear();
    });
    if (mounted) {
      LumaHaptics.commit();
      LumaToast.show(
        context,
        'Drained $count scans in one transaction',
        icon: Icons.cloud_done_outlined,
        tone: LumaToastTone.verified,
      );
    }
  }

  Widget _buildConfirmTab(BuildContext context, TokenView view, LaMPState state) {
    final c = context.lamp;
    final token = view.token;

    // The gate reads the ledger, not the off-chain carton rows. A pharmacy
    // can only sign for what the ledger says arrived.
    final scannedCount = token.scanned;
    final totalCartons = token.declaredCartons;
    final allScanned = token.isFullyScanned;

    String? gateCaption;
    if (!allScanned) {
      gateCaption = 'Scan all $totalCartons cartons before signing';
    } else if (!_hasSignature) {
      gateCaption = 'Sign above to enable submission';
    }

    return ListView(
      padding: lumaScrollPadding(context, top: Gap.lg),
      children: [
        LampCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LampEyebrow("Pharmacist's signature"),
              const SizedBox(height: Gap.xs),
              Text(
                view.pharmacy?.name ?? token.buyerDid,
                style: LaMPType.title.copyWith(color: c.ink),
              ),
              Text(
                'The pharmacist signs for the cartons scanned in.',
                style: LaMPType.caption.copyWith(color: c.inkMuted),
              ),
              Divider(height: Gap.xl, thickness: 1, color: c.line),
              LampKeyValue(label: 'Invoice', value: token.invoiceId, mono: true),
              LampKeyValue(
                label: 'Invoice total',
                value: LaMPFormatters.formatBDT(token.declaredValue),
                mono: true,
              ),
              LampKeyValue(
                label: 'Cartons received',
                value: '$scannedCount of $totalCartons',
                mono: true,
              ),
              LampKeyValue(label: 'Terms', value: '${token.termsDays} days'),
              const SizedBox(height: Gap.lg),
              SignaturePad(
                onSigned: (hasInk) => setState(() => _hasSignature = hasInk),
              ),
              const SizedBox(height: Gap.lg),
              if (gateCaption != null) ...[
                Row(
                  children: [
                    const LampStateDot(LampState.pending),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Text(
                        gateCaption,
                        style: LaMPType.meta.copyWith(color: c.pending),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.md),
              ],
              ElevatedButton.icon(
                // Both gates must be open: every carton on the ledger AND ink
                // on the pad.
                onPressed: (allScanned && _hasSignature)
                    ? () async {
                        await state.confirmDelivery(
                            token.tokenId, 'mock-signature-stroke');
                        if (context.mounted) {
                          LumaHaptics.commit();
                          LumaToast.show(
                            context,
                            'Delivered. Dispute window open 24h.',
                            icon: Icons.check_circle_outline,
                            tone: LumaToastTone.verified,
                          );
                          _goTo(0);
                        }
                      }
                    : null,
                icon: const Icon(Icons.check_circle_outline, size: IconSize.md),
                label: const Text('Confirm delivery'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReturnsTab(BuildContext context, TokenView view, LaMPState state) {
    final c = context.lamp;
    final delivery = view.delivery!;
    return ListView(
      padding: lumaScrollPadding(context, top: Gap.lg),
      children: [
        LampCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LampEyebrow('Returns'),
              const SizedBox(height: Gap.xs),
              Text(
                'Report a damaged or misrouted carton',
                style: LaMPType.head.copyWith(color: c.ink),
              ),
              Text(
                'Raises a dispute on ${view.token.invoiceId}. The invoice '
                "can't be financed while the dispute is open.",
                style: LaMPType.caption.copyWith(color: c.inkMuted),
              ),
              Divider(height: Gap.xl, thickness: 1, color: c.line),
              Row(
                children: [
                  Icon(Icons.report_problem_outlined,
                      color: c.inkMuted, size: IconSize.lg),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Damage in transit',
                            style: LaMPType.sub.copyWith(color: c.ink)),
                        Text('Seals broken in transit',
                            style: LaMPType.caption.copyWith(color: c.inkFaint)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.lg),
              // Refused colour on the label and outline, never as a fill.
              OutlinedButton.icon(
                onPressed: () async {
                  await state.raiseDispute(
                      delivery.tokenId, 'Damage in transit reported by MPO');
                  if (context.mounted) {
                    LumaHaptics.reject();
                    LumaToast.show(
                      context,
                      'Dispute raised',
                      icon: Icons.flag_outlined,
                      tone: LumaToastTone.dispute,
                    );
                  }
                },
                icon: const Icon(Icons.flag_outlined, size: IconSize.md),
                label: const Text('Flag carton'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: c.dispute,
                  side: BorderSide(color: c.dispute),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
