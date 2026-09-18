import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/chain/crypto.dart';
import '../../core/constants/app_theme.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/formatters.dart';
import '../../core/models/domain_models.dart';
import '../../core/state/lamp_state.dart';
import '../../widgets/carton_code_view.dart';
import '../../widgets/carton_scanner_sheet.dart';
import '../../widgets/data_matrix_view.dart';
import '../../widgets/demo_director_sheet.dart';
import '../../widgets/ledger_inspector_sheet.dart';
import '../../widgets/signature_pad.dart';
import '../../widgets/lamp_mark.dart';
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
    final state = context.watch<LaMPState>();
    final delivery = state.getDelivery(state.demoTokenId);

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
                  const Flexible(
                    child: Text(
                      'MPO Delivery App',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: LaMPColors.fieldInk),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.wifi, size: 14, color: LaMPColors.brand),
                ],
              ),
              Text(
                'Kamrul Hasan · LMP-DEV-4471 · Bogura Sadar',
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
              Tab(text: "Today's Route"),
              Tab(text: "Carton Scanner"),
              Tab(text: "Pharmacy Sign"),
              Tab(text: "Returns"),
            ],
          ),
        ),
        body: delivery == null
            ? const Center(child: CircularProgressIndicator())
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
    final scannedCount = delivery.cartons.where((c) => c.scannedAt != null).length;
    final totalCartons = delivery.cartons.length;
    final ratio = totalCartons > 0 ? scannedCount / totalCartons : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: LaMPColors.brandSoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'STOP 1 OF 1',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: LaMPColors.brand),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: delivery.status == DeliveryStatus.completed
                                ? LaMPColors.verifiedSoft
                                : LaMPColors.pendingSoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            delivery.status.id,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: delivery.status == DeliveryStatus.completed
                                  ? LaMPColors.verifiedDark
                                  : LaMPColors.pending,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Rahman Medical Hall',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: LaMPColors.fieldInk),
                    ),
                    const Text(
                      'রহমান মেডিকেল হল · Sherpur Road, Bogura Sadar',
                      style: TextStyle(fontSize: 12, color: LaMPColors.fieldInk2),
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: LaMPColors.fieldLine, height: 1),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('INVOICE ID', style: TextStyle(fontSize: 10, color: LaMPColors.fieldInk3)),
                            Text(delivery.invoiceId,
                                style: const TextStyle(fontSize: 14, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('CARTONS', style: TextStyle(fontSize: 10, color: LaMPColors.fieldInk3)),
                            Text('$scannedCount / $totalCartons',
                                style: const TextStyle(fontSize: 14, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('VALUE', style: TextStyle(fontSize: 10, color: LaMPColors.fieldInk3)),
                            Text(LaMPFormatters.formatBDT(182400),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor: LaMPColors.fieldLine,
                        valueColor: const AlwaysStoppedAnimation<Color>(LaMPColors.brand),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(ratio * 100).toInt()}% consignment verified on blockchain',
                      style: const TextStyle(fontSize: 11, color: LaMPColors.fieldInk3),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _tabController.animateTo(1),
                        icon: const Icon(Icons.qr_code_scanner, size: 18),
                        label: Text(scannedCount >= totalCartons ? 'Review Scanned Cartons' : 'Start Carton Scan'),
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

              // Items Manifest
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
                    const Text(
                      'Consignment Manifest (Shomota Pharma)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: LaMPColors.fieldInk),
                    ),
                    const SizedBox(height: 10),
                    _manifestRow('Paracetamol 500mg (SHM-PARA-500)', '10 cartons', '50,000 tabs'),
                    _manifestRow('Esomeprazole 20mg (SHM-ESOM-20)', '8 cartons', '9,600 caps'),
                    _manifestRow('Metformin HCl 500mg (SHM-METF-500)', '7 cartons', '21,000 tabs'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _manifestRow(String name, String cartons, String units) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          Text(cartons, style: const TextStyle(fontSize: 12, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text(units, style: const TextStyle(fontSize: 11, color: LaMPColors.fieldInk3)),
        ],
      ),
    );
  }

  Widget _buildScannerTab(BuildContext context, Delivery delivery, LaMPState state) {
    final scannedCount = delivery.cartons.where((c) => c.scannedAt != null).length;
    final totalCartons = delivery.cartons.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Scanner Status Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: LaMPColors.fieldLine),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SCAN PROGRESS', style: TextStyle(fontSize: 10, color: LaMPColors.fieldInk3)),
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
                          activeThumbColor: LaMPColors.pending,
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
                            color: _offlineMode ? LaMPColors.pending : LaMPColors.brand,
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
                    color: LaMPColors.disputeSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: LaMPColors.dispute),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: LaMPColors.dispute, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _scanBannerError!,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: LaMPColors.dispute),
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
                      backgroundColor: LaMPColors.brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
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
                  onPressed: _showMisroutedCode,
                  icon: const Icon(Icons.report_gmailerrorred_outlined, size: 16),
                  label: const Text(
                    'Show a misrouted carton code',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: LaMPColors.dispute,
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
                              foregroundColor: LaMPColors.brand,
                              side: const BorderSide(color: LaMPColors.brand),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: () => _scanNextCarton(state, delivery),
                            icon: const Icon(Icons.touch_app_outlined, size: 18),
                            label: const Text('Scan Next Carton'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: LaMPColors.brand,
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
                      side: BorderSide(color: _autoScanning ? LaMPColors.dispute : LaMPColors.brand),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    child: Text(
                      _autoScanning ? 'Stop Auto' : 'Auto Cascade',
                      style: TextStyle(
                        color: _autoScanning ? LaMPColors.dispute : LaMPColors.brand,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (!cameraScanningSupported) ...[
                const SizedBox(height: 8),
                Text(
                  'Camera scanning runs on Android and iOS. This build is using '
                  'the on-screen cascade.',
                  style: TextStyle(
                    fontSize: 11,
                    color: LaMPColors.fieldInk3,
                    height: 1.3,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // List of 25 Cartons
              const Text(
                'Consignment Cartons (Sequential Proof)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: LaMPColors.fieldInk),
              ),
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: delivery.cartons.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (ctx, i) {
                  final c = delivery.cartons[i];
                  final isScanned = c.scannedAt != null;
                  final isRejected = c.rejected == true;
                  final isPlant = (i == 13); // Carton 14 (0-indexed 13)

                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isRejected
                            ? LaMPColors.dispute
                            : (isScanned ? LaMPColors.verified : LaMPColors.fieldLine),
                        width: isRejected || isScanned ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Tapping enlarges the carton's code into something a
                        // second device can actually read.
                        InkWell(
                          onTap: () => _showCartonCode(c),
                          borderRadius: BorderRadius.circular(4),
                          child: DataMatrixView(text: c.gs1, size: 40),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                children: [
                                  Text(
                                    c.cartonId,
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
                                '${c.sku} · ${c.batch} · Exp ${c.expiry}',
                                style: const TextStyle(fontSize: 10, color: LaMPColors.fieldInk3),
                              ),
                            ],
                          ),
                        ),
                        if (isRejected)
                          const Icon(Icons.cancel, color: LaMPColors.dispute, size: 18)
                        else if (isScanned)
                          const Icon(Icons.check_circle, color: LaMPColors.verified, size: 18)
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
  void _showMisroutedCode() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: LaMPColors.fieldSurface,
        title: const Text(
          'Misrouted carton',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This carton belongs to no consignment in this world. Scan it '
                'with the camera and the chaincode will refuse it — the '
                'refusal is genuine, not staged.',
                style: TextStyle(fontSize: 12, height: 1.4, color: LaMPColors.fieldInk2),
              ),
              const SizedBox(height: 14),
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
  void _showCartonCode(Carton carton) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: LaMPColors.fieldSurface,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Carton ${targetCarton.cartonId} queued offline (${_offlineQueue.length} queued)'),
          duration: const Duration(milliseconds: 700),
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Drained $count offline scans in 1 batch transaction!')),
      );
    }
  }

  Widget _buildConfirmTab(BuildContext context, Delivery delivery, LaMPState state) {
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
                    const Text(
                      'Pharmacy Counter-Confirmation',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: LaMPColors.fieldInk),
                    ),
                    const Text(
                      'Abdur Rahman signs on MPO device to generate verifiable Proof of Delivery',
                      style: TextStyle(fontSize: 12, color: LaMPColors.fieldInk2),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: LaMPColors.fieldLine, height: 1),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Invoice Total:', style: TextStyle(fontSize: 13, color: LaMPColors.fieldInk2)),
                        Text(LaMPFormatters.formatBDT(182400),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Cartons Received:', style: TextStyle(fontSize: 13, color: LaMPColors.fieldInk2)),
                        Text('${delivery.cartons.length} cartons',
                            style: const TextStyle(fontSize: 13, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Payment Terms:', style: TextStyle(fontSize: 13, color: LaMPColors.fieldInk2)),
                        const Text('45 Days Credit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
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

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _hasSignature
                            ? () async {
                                await state.confirmDelivery(delivery.tokenId, 'mock-signature-stroke');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Delivery Confirmed! 24h Dispute Window is now active on-chain.'),
                                    ),
                                  );
                                  _tabController.animateTo(0);
                                }
                              }
                            : null,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Confirm Receipt & Submit PoD'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LaMPColors.brand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                    const Text(
                      'Reverse Carton Scan / Returns',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: LaMPColors.fieldInk),
                    ),
                    const Text(
                      'Report damaged or misrouted carton to reopen receivable token',
                      style: TextStyle(fontSize: 12, color: LaMPColors.fieldInk2),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.report_problem_outlined, color: LaMPColors.pending),
                      title: const Text('Damage in Transit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Carton seals broken or crushed during delivery'),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          await state.raiseDispute(delivery.tokenId, 'Damage in transit reported by MPO');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Dispute raised on ledger. Status: DISPUTED')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LaMPColors.pending,
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
