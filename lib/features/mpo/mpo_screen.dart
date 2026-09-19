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
    final delivery = state.getDelivery(state.demoTokenId);
    final c = context.lamp;

    return Scaffold(
      extendBodyBehindAppBar: true,
      // One bar for all five seats — see `LumaAppBar`. This one used to set
      // `elevation: 1`, which gave it a drop shadow no other screen had; the
      // separation is now a hairline under glass, and the content scrolls
      // visibly beneath it.
      appBar: LumaAppBar(
        title: 'Delivery officer',
        subtitle: 'Kamrul Hasan · LMP-DEV-4471 · Bogura Sadar',
        onBack: widget.onBackToLauncher,
        actions: [
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
          builder: (context) => delivery == null
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
                    _buildRouteTab(context, delivery, state),
                    _buildScannerTab(context, delivery, state),
                    _buildConfirmTab(context, delivery, state),
                    _buildReturnsTab(context, delivery, state),
                  ],
                ),
        ),
    );
  }

  Widget _buildRouteTab(BuildContext context, Delivery delivery, LaMPState state) {
    final c = context.lamp;
    final scannedCount = delivery.cartons.where((c) => c.scannedAt != null).length;
    final totalCartons = delivery.cartons.length;
    final ratio = totalCartons > 0 ? scannedCount / totalCartons : 0.0;

    return SingleChildScrollView(
      padding: lumaScrollPadding(context, top: Gap.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Delivery Route Card
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: c.brandSoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Stop 1 of 1',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c.brand),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: delivery.status == DeliveryStatus.completed
                                ? c.verifiedSoft
                                : c.pendingSoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            delivery.status.id,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: delivery.status == DeliveryStatus.completed
                                  ? c.verified
                                  : c.pending,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Rahman Medical Hall',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.ink),
                    ),
                    Text(
                      'রহমান মেডিকেল হল · Sherpur Road, Bogura Sadar',
                      style: TextStyle(fontSize: 12, color: c.inkMuted),
                    ),
                    const SizedBox(height: 12),
                    Divider(color: c.line, height: 1),
                    const SizedBox(height: 12),
                    // Three figures sharing the width. Unflexed beside a
                    // spaceBetween they claimed their natural widths and
                    // overflowed a 360dp phone by 62 pixels; LampStat scales
                    // its figure down rather than pushing its neighbours off.
                    //
                    // The gutter is the other half of that, and it took a
                    // real phone to see: the invoice id is long enough to be
                    // scaled to exactly its column, so with the columns flush
                    // it printed as `INV-002350/25`. See [LampStatRow].
                    LampStatRow(
                      children: [
                        LampStat(
                          label: 'Invoice',
                          value: delivery.invoiceId,
                        ),
                        LampStat(
                          label: 'Cartons',
                          value: '$scannedCount/$totalCartons',
                        ),
                        LampStat(
                          label: 'Value',
                          value: LaMPFormatters.formatBDT(182400),
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
                      '${(ratio * 100).toInt()}% verified',
                      style: TextStyle(fontSize: 11, color: c.inkFaint),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _tabController.animateTo(1),
                        icon: const Icon(Icons.qr_code_scanner, size: 18),
                        label: Text(scannedCount >= totalCartons ? 'Review Scanned Cartons' : 'Start Carton Scan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.brand,
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

              // Items Manifest
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
                      'Manifest',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.ink),
                    ),
                    const SizedBox(height: 8),
                    _manifestRow(context, 'Paracetamol 500mg (SHM-PARA-500)', '10 cartons', '50,000 tabs'),
                    _manifestRow(context, 'Esomeprazole 20mg (SHM-ESOM-20)', '8 cartons', '9,600 caps'),
                    _manifestRow(context, 'Metformin HCl 500mg (SHM-METF-500)', '7 cartons', '21,000 tabs'),
                  ],
                ),
              ),
            ],
          ),
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

  Widget _buildScannerTab(BuildContext context, Delivery delivery, LaMPState state) {
    final c = context.lamp;
    final scannedCount = delivery.cartons.where((c) => c.scannedAt != null).length;
    final totalCartons = delivery.cartons.length;

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
                      foregroundColor: Colors.white,
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
                              foregroundColor: Colors.white,
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
              ListView.separated(
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
                                        color: Colors.purple.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: const Text('MISROUTED TEST',
                                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.purple)),
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
                          const Icon(Icons.radio_button_unchecked, color: Colors.black26, size: 18),
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
                      foregroundColor: Colors.white,
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
              'LMP-DEV-4471',
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

  void _scanNextCarton(LaMPState state, Delivery delivery) async {
    // Find next unscanned carton
    final unscannedIndex = delivery.cartons.indexWhere((c) => c.scannedAt == null);
    if (unscannedIndex == -1) {
      _autoTimer?.cancel();
      setState(() => _autoScanning = false);
      return;
    }

    final targetCarton = delivery.cartons[unscannedIndex];

    // Check if this is the planted foreign carton (#14 -> index 13)
    // On the real demo, Carton 14 is presented with a foreign payload
    if (unscannedIndex == 13 && targetCarton.rejected != true) {
      // Send foreign barcode to trigger genuine chaincode refusal!
      await state.scanCarton(delivery.tokenId, _misroutedGs1, 'LMP-DEV-4471');
      setState(() {
        _scanBannerError = 'CHAINCODE REFUSED: Carton does not belong to invoice ${delivery.invoiceId}. Product rejected!';
        targetCarton.rejected = true;
      });
      return;
    }

    if (_offlineMode) {
      _offlineQueue.add(targetCarton.gs1);
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
      await state.scanCarton(delivery.tokenId, targetCarton.gs1, 'LMP-DEV-4471');
    }
  }

  void _toggleAutoScan(LaMPState state, Delivery delivery) {
    if (_autoScanning) {
      _autoTimer?.cancel();
      setState(() => _autoScanning = false);
    } else {
      setState(() => _autoScanning = true);
      _autoTimer = Timer.periodic(const Duration(milliseconds: 650), (t) {
        final unscanned = delivery.cartons.any((c) => c.scannedAt == null);
        if (!unscanned) {
          t.cancel();
          setState(() => _autoScanning = false);
        } else {
          _scanNextCarton(state, delivery);
        }
      });
    }
  }

  void _drainQueue(LaMPState state, String tokenId) async {
    if (_offlineQueue.isEmpty) return;
    final count = _offlineQueue.length;
    await state.drainScanQueue(tokenId, List.from(_offlineQueue), 'LMP-DEV-4471');
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

  Widget _buildConfirmTab(BuildContext context, Delivery delivery, LaMPState state) {
    final c = context.lamp;
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
                      label: 'Invoice total',
                      value: LaMPFormatters.formatBDT(182400),
                      mono: true,
                    ),
                    LampKeyValue(
                      label: 'Cartons received',
                      value: '${delivery.cartons.length}',
                      mono: true,
                    ),
                    const LampKeyValue(label: 'Terms', value: '45 days'),
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

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _hasSignature
                            ? () async {
                                await state.confirmDelivery(delivery.tokenId, 'mock-signature-stroke');
                                if (context.mounted) {
                                  LumaHaptics.commit();
                                  LumaToast.show(
                                    context,
                                    'Delivered. Dispute window open 24h.',
                                    icon: Icons.check_circle_outline,
                                    tone: LumaToastTone.verified,
                                  );
                                  _tabController.animateTo(0);
                                }
                              }
                            : null,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Confirm Receipt & Submit PoD'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.brand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          disabledBackgroundColor: Colors.black12,
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

  Widget _buildReturnsTab(BuildContext context, Delivery delivery, LaMPState state) {
    final c = context.lamp;
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
                          foregroundColor: Colors.white,
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
