import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/constants/colors.dart';
import 'ui/lamp_skeleton.dart';

/// What the chaincode made of a scanned payload.
class CartonScanResult {
  final bool accepted;
  final String message;

  const CartonScanResult({required this.accepted, required this.message});
}

/// Is there a camera worth offering on this platform?
///
/// mobile_scanner supports the browser, but DataMatrix decoding there goes
/// through a JS fallback that is markedly less reliable than the native MLKit
/// path — offering it on web would mean demonstrating the weakest version of
/// the feature. Desktop has no implementation at all.
bool get cameraScanningSupported {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// Live carton scanning.
///
/// The sheet decodes and displays; it decides nothing. Every payload it reads
/// is handed to [onPayload] exactly as it came off the camera — never a hash,
/// and never pre-filtered against the expected set — so a carton that does not
/// belong to the consignment is refused by the chaincode's own membership test
/// rather than by the UI deciding in advance.
class CartonScannerSheet extends StatefulWidget {
  final String invoiceId;
  final int scannedCount;
  final int totalCartons;
  final Future<CartonScanResult> Function(String payload) onPayload;

  const CartonScannerSheet({
    super.key,
    required this.invoiceId,
    required this.scannedCount,
    required this.totalCartons,
    required this.onPayload,
  });

  @override
  State<CartonScannerSheet> createState() => _CartonScannerSheetState();
}

class _CartonScannerSheetState extends State<CartonScannerSheet> {
  late final MobileScannerController _controller;

  /// Payloads already handled, so a code held in frame is not submitted on
  /// every detection callback. The camera fires several times a second.
  final Set<String> _seen = {};

  bool _busy = false;
  bool _torchOn = false;
  int _scanned = 0;
  CartonScanResult? _last;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _scanned = widget.scannedCount;
    _controller = MobileScannerController(
      // GS1 cartons carry a DataMatrix. QR is accepted too so the codes the
      // app renders on screen can be scanned from a second device, which is
      // the only way to exercise this without printed labels.
      formats: const [BarcodeFormat.dataMatrix, BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 400,
    );
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handle(BarcodeCapture capture) async {
    if (_busy) return;

    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null || _seen.contains(raw)) return;

    _seen.add(raw);
    setState(() => _busy = true);

    final result = await widget.onPayload(raw);
    if (!mounted) return;

    setState(() {
      _busy = false;
      _last = result;
      if (result.accepted) _scanned += 1;
    });

    // A refused carton stays readable for longer — it is the thing the
    // operator has to act on.
    _bannerTimer?.cancel();
    _bannerTimer = Timer(
      Duration(milliseconds: result.accepted ? 1400 : 3200),
      () {
        if (mounted) setState(() => _last = null);
      },
    );

    // A refusal must be re-scannable: the same carton may be presented again
    // once the operator has checked it against the manifest.
    if (!result.accepted) _seen.remove(raw);

    if (_scanned >= widget.totalCartons && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _last;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handle,
            onDetectError: (error, _) =>
                debugPrint('CartonScanner: detection error $error'),
            errorBuilder: (context, error) => _CameraUnavailable(error: error),
          ),

          _ScannerReticle(accepted: last?.accepted),

          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  invoiceId: widget.invoiceId,
                  scanned: _scanned,
                  total: widget.totalCartons,
                  torchOn: _torchOn,
                  onTorch: () async {
                    await _controller.toggleTorch();
                    if (mounted) setState(() => _torchOn = !_torchOn);
                  },
                  onClose: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                if (last != null) _ResultBanner(result: last),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Point the camera at the code on the carton. '
                    'Each scan is submitted to the chaincode as it is read.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          if (_busy)
            const Positioned(
              bottom: 140,
              left: 0,
              right: 0,
              child: Center(
                child: LampBusy(size: 22, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String invoiceId;
  final int scanned;
  final int total;
  final bool torchOn;
  final VoidCallback onTorch;
  final VoidCallback onClose;

  const _TopBar({
    required this.invoiceId,
    required this.scanned,
    required this.total,
    required this.torchOn,
    required this.onTorch,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      color: Colors.black.withValues(alpha: 0.55),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onClose,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoiceId,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '$scanned of $total cartons verified',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              torchOn ? Icons.flash_on : Icons.flash_off,
              color: torchOn ? LaMPColors.pending : Colors.white,
            ),
            onPressed: onTorch,
          ),
        ],
      ),
    );
  }
}

class _ScannerReticle extends StatelessWidget {
  /// null while idle, true on the last accepted scan, false on a refusal.
  final bool? accepted;

  const _ScannerReticle({required this.accepted});

  @override
  Widget build(BuildContext context) {
    final colour = accepted == null
        ? Colors.white70
        : (accepted! ? LaMPColors.verified : LaMPColors.dispute);

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          border: Border.all(color: colour, width: 3),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  final CartonScanResult result;

  const _ResultBanner({required this.result});

  @override
  Widget build(BuildContext context) {
    final colour = result.accepted ? LaMPColors.verified : LaMPColors.dispute;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colour,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            result.accepted ? Icons.verified : Icons.block,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result.message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  final MobileScannerException error;

  const _CameraUnavailable({required this.error});

  @override
  Widget build(BuildContext context) {
    final denied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            denied ? Icons.no_photography_outlined : Icons.videocam_off_outlined,
            color: Colors.white54,
            size: 44,
          ),
          const SizedBox(height: 16),
          Text(
            denied ? 'Camera permission denied' : 'Camera unavailable',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            denied
                ? 'Grant camera access in system settings, or close this and use '
                    'the on-screen cascade instead.'
                : error.errorDetails?.message ?? 'No camera could be started.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
