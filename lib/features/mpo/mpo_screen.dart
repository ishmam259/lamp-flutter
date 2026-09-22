import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/chain/crypto.dart';
import '../../core/constants/app_theme.dart';
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
import '../../widgets/ui/lamp_skeleton.dart';
import '../../widgets/theme_toggle.dart';
import '../../widgets/ui/lamp_ui.dart';
import '../../widgets/carton_scanner_sheet.dart';
import '../../widgets/data_matrix_view.dart';
import '../../widgets/demo_director_sheet.dart';
import '../../widgets/ledger_inspector_sheet.dart';
import '../../widgets/signature_pad.dart';
import '../../core/constants/typography.dart';

class MpoScreen extends StatefulWidget {
  final VoidCallback onBackToLauncher;

  const MpoScreen({super.key, required this.onBackToLauncher});

  @override
  State<MpoScreen> createState() => _MpoScreenState();
}

class _MpoScreenState extends State<MpoScreen> with SingleTickerProviderStateMixin {
  /// A carton belonging to no consignment in this world.
  ///
  /// The scan cascade substitutes this at position 14, and the same payload is
  /// offered as a scannable code so the camera path can be refused too. It has
  /// to be one string: two literals that drifted apart would leave the camera
  /// demo quietly accepting what the tap demo refuses.
  static const String _misroutedGs1 =
      '(01)08901234001019(17)280824(10)BCH-FOREIGN(21)SN-9999';

  late TabController _tabController;
  bool _offlineMode = false;
  final List<String> _offlineQueue = [];
  bool _autoScanning = false;
  Timer? _autoTimer;
  String? _scanBannerError;
  bool _hasSignature = false;

  /// The stop the Scan, Sign and Returns tabs are working on.
  ///
  /// The screen used to read one hard-coded consignment, which is why a
  /// completed delivery stayed on the route with nothing behind it and a
  /// newly minted one appeared nowhere.
  String? _activeTokenId;

  /// This device's officer. One seat, but read from the seed rather than
  /// re-typed as a literal in five places.
  Mpo get _me => SeedData.mpos[0];

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _tabController.dispose();
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
      // One bar for all five seats — see `LumaAppBar`. This one used to set
      // `elevation: 1`, which gave it a drop shadow no other screen had; the
      // separation is now a hairline under glass, and the content scrolls
      // visibly beneath it.
      appBar: LumaAppBar(
        title: 'Delivery officer',
        // From the seed rather than three literals. The identity line used to
        // be hardcoded, so it disagreed with the device id every other screen
        // read from `_me`.
        subtitle: '${_me.name} · ${_me.deviceId} · ${_me.territory}',
        onBack: widget.onBackToLauncher,
        actions: [
          // Tracks the switch on the Scan tab. It was always the connected
          // glyph, including while the device was queuing scans because it
          // had no signal.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
            child: Center(
              child: Icon(
                _offlineMode ? Icons.wifi_off : Icons.wifi,
                size: IconSize.sm,
                color: _offlineMode ? c.pending : c.brand,
              ),
            ),
          ),
          const ThemeToggle(),
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
            Tab(text: 'Route'),
            Tab(text: 'Scan'),
            Tab(text: 'Sign'),
            Tab(text: 'Returns'),
          ],
        ),
      ),
        // The Builder is load-bearing: under it, `MediaQuery.padding.top`
        // carries the height of the bar and its tab strip, which is what
        // `lumaScrollPadding` reads in each tab below. Outside it, the same
        // call would return the status bar alone and every tab would start
        // its content behind the glass.
        // No SafeArea. It would apply the bottom inset as padding and remove
        // it from the MediaQuery underneath — and the tabs below read that
        // inset themselves, through `lumaScrollPadding`, so it would be
        // counted twice and every list would stop a gesture bar short of the
        // bottom of the screen.
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
              : TabBarView(
                  controller: _tabController,
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
    );
  }

  /// What the working tabs show when the round is done.
  Widget _noStop(BuildContext context, String message) {
    final c = context.lamp;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 40, color: c.verified),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.inkMuted),
            ),
            const SizedBox(height: 4),
            Text(
              'Every consignment assigned to this device has been handed over.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: c.inkFaint),
            ),
          ],
        ),
      ),
    );
  }

  /// Today's round.
  ///
  /// A stop leaves this list once the ledger holds every carton and the
  /// pharmacy has signed — the same two conditions as `app/mpo/page.tsx:28-36`.
  /// Before this the tab drew one hard-coded stop, so a completed delivery sat
  /// there permanently and a freshly minted consignment never appeared.
  Widget _buildRouteTab(
    BuildContext context,
    List<TokenView> route,
    LaMPState state,
  ) {
    final c = context.lamp;
    final activeId = _activeStop(state)?.tokenId;
    final cartonsLeft = route.fold<int>(
      0,
      (sum, TokenView v) =>
          sum + (v.token.declaredCartons - v.token.scanned).clamp(0, 1 << 30),
    );

    return SingleChildScrollView(
      padding: lumaScrollPadding(context, top: Gap.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.line),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: LampStat(label: 'Stops', value: '${route.length}'),
                    ),
                    Expanded(
                      child: LampStat(label: 'Cartons', value: '$cartonsLeft'),
                    ),
                    Expanded(
                      child: LampStat(
                        label: 'Date',
                        value: LaMPFormatters.formatDateShort(state.now),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (route.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 32,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.line),
                  ),
                  child: Text(
                    'No deliveries assigned today.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: c.inkFaint),
                  ),
                )
              else
                for (int i = 0; i < route.length; i++) ...[
                  _stopCard(
                    context,
                    route[i],
                    state,
                    position: i + 1,
                    total: route.length,
                    selected: route[i].tokenId == activeId,
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }

  /// One stop on the round. Tapping it selects it for the working tabs, and
  /// the selected one opens to show its manifest.
  Widget _stopCard(
    BuildContext context,
    TokenView view,
    LaMPState state, {
    required int position,
    required int total,
    required bool selected,
  }) {
    final c = context.lamp;
    final token = view.token;
    final pharmacy = view.pharmacy;
    final scanned = token.scanned;
    final declared = token.declaredCartons;
    final ratio = declared == 0 ? 0.0 : scanned / declared;
    final complete = token.isFullyScanned;

    final status = switch (view.delivery?.status) {
      DeliveryStatus.completed => ('DELIVERED', c.verified, c.verifiedSoft),
      DeliveryStatus.awaitingConfirmation => (
          'AWAITING SIGNATURE',
          c.pending,
          c.pendingSoft
        ),
      DeliveryStatus.scanning => ('SCANNING', c.pending, c.pendingSoft),
      DeliveryStatus.disputed => ('DISPUTED', c.dispute, c.disputeSoft),
      _ => ('PENDING', c.pending, c.pendingSoft),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _activeTokenId = token.tokenId),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? c.brand : c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A Wrap, not a Row. "Awaiting signature" beside the stop
            // counter runs 35 pixels off a 360dp phone, and a status the
            // officer needs to read is not something to ellipsise — so it
            // drops to its own line instead.
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: c.brandSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Stop $position of $total',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: c.brand,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: status.$3,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status.$1,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: status.$2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              pharmacy?.name ?? token.buyerDid,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: c.ink,
              ),
            ),
            if (pharmacy != null)
              Text(
                '${pharmacy.nameBn} · ${pharmacy.address}',
                style: TextStyle(fontSize: 12, color: c.inkMuted),
              ),
            const SizedBox(height: 12),
            Divider(color: c.line, height: 1),
            const SizedBox(height: 12),
            // Three figures sharing the width. Unflexed beside a
            // spaceBetween they claimed their natural widths and
            // overflowed a 360dp phone by 62 pixels; LampStat scales
            // its figure down rather than pushing its neighbours off.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LampStat(label: 'Invoice', value: token.invoiceId),
                ),
                Expanded(
                  child: LampStat(
                    label: 'Cartons',
                    value: '$scanned/$declared',
                  ),
                ),
                Expanded(
                  child: LampStat(
                    label: 'Value',
                    value: LaMPFormatters.formatBDT(token.declaredValue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: c.line,
                valueColor: AlwaysStoppedAnimation<Color>(c.brand),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(ratio * 100).toInt()}% verified on the ledger',
              style: TextStyle(fontSize: 11, color: c.inkFaint),
            ),

            if (selected) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _activeTokenId = token.tokenId);
                    _tabController.animateTo(complete ? 2 : 1);
                  },
                  icon: Icon(
                    complete ? Icons.draw_outlined : Icons.qr_code_scanner,
                    size: 18,
                  ),
                  label: Text(
                    complete
                        ? 'Hand over and sign'
                        : scanned == 0
                            ? 'Start carton scan'
                            : 'Continue scanning ($scanned/$declared)',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.brand,
                    foregroundColor: c.onBrand,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Manifest',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 4),
              // Read off the invoice. These were three literal rows naming
              // Paracetamol, Esomeprazole and Metformin whatever the
              // consignment actually held.
              if (view.invoice == null)
                Text(
                  'No line items recorded for this consignment.',
                  style: TextStyle(fontSize: 11, color: c.inkFaint),
                )
              else
                for (final line in view.invoice!.lineItems)
                  _manifestRow(
                    context,
                    '${line.name} ${line.strength} (${line.sku})',
                    '${line.cartons} cartons',
                    '${LaMPFormatters.formatBDTPlain(line.quantity)} units',
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _manifestRow(BuildContext context, String name, String cartons, String units) {
    final c = context.lamp;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          Text(cartons, style: const TextStyle(fontSize: 12, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text(units, style: TextStyle(fontSize: 11, color: c.inkFaint)),
        ],
      ),
    );
  }

  Widget _buildScannerTab(BuildContext context, TokenView view, LaMPState state) {
    final c = context.lamp;
    final delivery = view.delivery!;
    // Counts come off the token. The off-chain rows are what drive the
    // per-carton ticks below, but the ledger is what decides whether this
    // consignment has been delivered.
    final scannedCount = view.token.scanned;
    final totalCartons = view.token.declaredCartons;

    return SingleChildScrollView(
      padding: lumaScrollPadding(context, top: Gap.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Scanner Status Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.line),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SCAN PROGRESS', style: TextStyle(fontSize: 10, color: c.inkFaint)),
                          Text('$scannedCount of $totalCartons verified',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Switch(
                          value: _offlineMode,
                          activeThumbColor: c.pending,
                          onChanged: (val) {
                            setState(() {
                              _offlineMode = val;
                            });
                            if (!val && _offlineQueue.isNotEmpty) {
                              _drainQueue(state, delivery.tokenId);
                            }
                          },
                        ),
                        Text(
                          _offlineMode ? 'OFFLINE' : 'ONLINE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _offlineMode ? c.pending : c.brand,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Rejection Banner (The BCOLBD Carton 14 shot)
              if (_scanBannerError != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.disputeSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.dispute),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: c.dispute, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _scanBannerError!,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.dispute),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setState(() => _scanBannerError = null),
                      ),
                    ],
                  ),
                ),

              // Scanner Action Buttons
              if (cameraScanningSupported) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openCameraScanner(state, delivery),
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text('Scan with camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.brand,
                      foregroundColor: c.onBrand,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Present a carton from no consignment to a second device, so
              // the camera can be refused by the chaincode on camera.
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showMisroutedCode(context),
                  icon: const Icon(Icons.report_gmailerrorred_outlined, size: 16),
                  label: const Text(
                    'Show a misrouted carton code',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: c.dispute,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: cameraScanningSupported
                        ? OutlinedButton.icon(
                            onPressed: () => _scanNextCarton(state, delivery),
                            icon: const Icon(Icons.touch_app_outlined, size: 18),
                            label: const Text('Scan Next Carton'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: c.brand,
                              side: BorderSide(color: c.brand),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: () => _scanNextCarton(state, delivery),
                            icon: const Icon(Icons.touch_app_outlined, size: 18),
                            label: const Text('Scan Next Carton'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.brand,
                              foregroundColor: c.onBrand,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _toggleAutoScan(state, delivery),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _autoScanning ? c.dispute : c.brand),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    child: Text(
                      _autoScanning ? 'Stop Auto' : 'Auto Cascade',
                      style: TextStyle(
                        color: _autoScanning ? c.dispute : c.brand,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (!cameraScanningSupported) ...[
                const SizedBox(height: 8),
                Text(
                  'Camera scanning runs on Android and iOS.',
                  style: TextStyle(
                    fontSize: 11,
                    color: c.inkFaint,
                    height: 1.3,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // List of 25 Cartons
              Text(
                'Cartons',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.ink),
              ),
              const SizedBox(height: 8),
              // Zero, and not left to default to null. A vertical ListView
              // with no padding quietly adopts `MediaQuery.padding` as its
              // own, which is meant for a list that *is* the scroll view.
              // This one is nested inside another, under a Scaffold with
              // `extendBodyBehindAppBar` — so the top inset it inherited had
              // the status bar, the app bar and the tab bar folded into it,
              // and it printed as an empty 490px band between the 'Cartons'
              // heading and CTN-1. The outer SingleChildScrollView already
              // reads the real insets through `lumaScrollPadding`.
              ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: delivery.cartons.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final carton = delivery.cartons[i];
                  final isScanned = carton.scannedAt != null;
                  final isRejected = carton.rejected == true;
                  final isPlant = (i == 13); // Carton 14 (0-indexed 13)

                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isRejected
                            ? c.dispute
                            : (isScanned ? c.verified : c.line),
                        width: isRejected || isScanned ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Tapping enlarges the carton's code into something a
                        // second device can actually read.
                        InkWell(
                          onTap: () => _showCartonCode(context, carton),
                          borderRadius: BorderRadius.circular(4),
                          child: DataMatrixView(text: carton.gs1, size: 40),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                children: [
                                  Text(
                                    carton.cartonId,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback,
                                    ),
                                  ),
                                  if (isPlant)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: c.disputeSoft,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text('MISROUTED TEST',
                                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: c.dispute)),
                                    ),
                                ],
                              ),
                              Text(
                                '${carton.sku} · ${carton.batch} · Exp ${carton.expiry}',
                                style: TextStyle(fontSize: 10, color: c.inkFaint),
                              ),
                            ],
                          ),
                        ),
                        if (isRejected)
                          Icon(Icons.cancel, color: c.dispute, size: 18)
                        else if (isScanned)
                          Icon(Icons.check_circle, color: c.verified, size: 18)
                        else
                          Icon(Icons.radio_button_unchecked, color: c.lineStrong, size: 18),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              if (scannedCount >= totalCartons)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _tabController.animateTo(2),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Proceed to Pharmacy Owner Signature →'),
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
                message: res.error ??
                    'Chaincode refused this carton for ${delivery.invoiceId}.',
              );
            }

            final hash = LaMPCrypto.sha256Hex(payload);
            final match = delivery.cartons.where((c) => c.hash == hash);
            final label = match.isEmpty ? 'Carton' : match.first.cartonId;
            final done =
                delivery.cartons.where((c) => c.scannedAt != null).length;

            return CartonScanResult(
              accepted: true,
              message: '$label recorded — $done of ${delivery.cartons.length}',
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
        title: const Text(
          'Misrouted carton',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This carton belongs to no consignment in this world. Scan it '
                'with the camera and the chaincode will refuse it — the '
                'refusal is genuine, not staged.',
                style: TextStyle(fontSize: 12, height: 1.4, color: c.inkMuted),
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
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
    if (unscannedIndex == 13 && targetCarton.rejected != true) {
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
      setState(() {
        _scanBannerError =
            'CHAINCODE REFUSED: Carton does not belong to invoice '
            '${delivery.invoiceId}. Product rejected!';
      });
      return;
    }

    if (_offlineMode) {
      // Queued, not recorded. The row is deliberately left unscanned: the
      // chaincode has not seen this carton yet, and `drainScanQueue` only
      // marks rows once it accepts the batch. Marking it here made a refused
      // batch leave every queued carton reading as verified.
      _offlineQueue.add(targetCarton.gs1);
      if (!mounted) return;
      setState(() {});
      // The receipt is for the queueing, not for a verification — the row
      // stays unmarked until `drainScanQueue` gets the batch accepted, which
      // is why the tone is pending rather than verified.
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

    // The gate reads the ledger, not the off-chain carton rows.
    //
    // It used to count `Carton.scannedAt`, which `confirmDelivery` then reset
    // to null on success — so the screen's idea of what had been handed over
    // disagreed with the chain's the moment anything was signed for. A
    // pharmacy can only sign for what the ledger says arrived.
    final scannedCount = token.scanned;
    final totalCartons = token.declaredCartons;
    final allScanned = token.isFullyScanned;

    // Build the caption that explains why the button is disabled, if it is.
    String? gateCaption;
    if (!allScanned) {
      gateCaption = 'Scan all $totalCartons cartons before signing';
    } else if (!_hasSignature) {
      gateCaption = 'Sign above to enable submission';
    }

    return SingleChildScrollView(
      padding: lumaScrollPadding(context, top: Gap.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pharmacy Counter-Confirmation',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.ink),
                    ),
                    Text(
                      'Sign to confirm delivery',
                      style: TextStyle(fontSize: 12, color: c.inkMuted),
                    ),
                    const SizedBox(height: 16),
                    Divider(color: c.line, height: 1),
                    const SizedBox(height: 16),

                    // Three label/value pairs, each of which was a
                    // spaceBetween that overflowed once the sweep could
                    // actually reach this tab.
                    LampKeyValue(
                      label: 'Invoice',
                      value: token.invoiceId,
                      mono: true,
                    ),
                    LampKeyValue(
                      label: 'Invoice total',
                      value: LaMPFormatters.formatBDT(token.declaredValue),
                      mono: true,
                    ),
                    LampKeyValue(
                      label: 'Cartons received',
                      // Live count of scanned cartons, not just the manifest
                      // total — a pharmacy can only confirm what actually
                      // arrived.
                      value: '$scannedCount of $totalCartons',
                      mono: true,
                    ),
                    LampKeyValue(
                      label: 'Terms',
                      value: '${token.termsDays} days',
                    ),
                    const SizedBox(height: 20),

                    // Signature Pad
                    SignaturePad(
                      onSigned: (hasInk) {
                        setState(() {
                          _hasSignature = hasInk;
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    if (gateCaption != null) ...[
                      Text(
                        gateCaption,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c.pending,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        // Both gates must be open: every carton scanned AND
                        // the signature pad has ink. A blank signature alone
                        // could previously submit; that is the user-reported
                        // "sign without goods" bug.
                        onPressed: (allScanned && _hasSignature)
                            ? () async {
                                final res = await state.confirmDelivery(
                                  token.tokenId,
                                  'mock-signature-stroke',
                                );
                                if (!context.mounted) return;
                                // Read off the token rather than printed as
                                // "24h": the window is policy, and a seeded
                                // world is free to set it to something else.
                                final hours =
                                    token.disputeWindowMs ~/ (3600 * 1000);
                                if (res.ok) {
                                  LumaHaptics.commit();
                                  LumaToast.show(
                                    context,
                                    'Delivered. Dispute window open ${hours}h.',
                                    icon: Icons.check_circle_outline,
                                    tone: LumaToastTone.verified,
                                  );
                                } else {
                                  LumaHaptics.reject();
                                  LumaToast.show(
                                    context,
                                    res.error ?? 'Refused',
                                    icon: Icons.error_outline,
                                    tone: LumaToastTone.dispute,
                                  );
                                }
                                if (res.ok) {
                                  setState(() {
                                    _hasSignature = false;
                                    _activeTokenId = null;
                                  });
                                  _tabController.animateTo(0);
                                }
                              }
                            : null,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Confirm Receipt & Submit PoD'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.brand,
                          foregroundColor: c.onBrand,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          disabledBackgroundColor: c.surfaceSunken,
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

  Widget _buildReturnsTab(BuildContext context, TokenView view, LaMPState state) {
    final c = context.lamp;
    final delivery = view.delivery!;
    return SingleChildScrollView(
      padding: lumaScrollPadding(context, top: Gap.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reverse Carton Scan / Returns',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.ink),
                    ),
                    Text(
                      'Report a damaged or misrouted carton',
                      style: TextStyle(fontSize: 12, color: c.inkMuted),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: Icon(Icons.report_problem_outlined, color: c.pending),
                      title: const Text('Damage in Transit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Seals broken in transit'),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          await state.raiseDispute(delivery.tokenId, 'Damage in transit reported by MPO');
                          if (context.mounted) {
                            LumaHaptics.reject();
                            LumaToast.show(
                              context,
                              'Dispute raised on ledger · DISPUTED',
                              icon: Icons.flag_outlined,
                              tone: LumaToastTone.dispute,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.pending,
                          foregroundColor: c.onBrand,
                        ),
                        child: const Text('Flag Carton'),
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
}
