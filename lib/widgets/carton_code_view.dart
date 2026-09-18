import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/constants/palette.dart';
import '../core/world/gs1.dart';
import '../core/constants/typography.dart';

/// A genuinely scannable rendering of a carton's GS1 payload.
///
/// A real carton carries a GS1 DataMatrix. Encoding ECC200 is several hundred
/// lines of Reed-Solomon that earn nothing here, so this renders the *same*
/// payload as a QR code — a different symbology carrying identical bytes. The
/// camera decodes it, the app hashes what it decoded, and the chaincode runs
/// its own membership test, so every link in the chain is exercised honestly.
/// The caption says which symbology it is; claiming it were a DataMatrix would
/// be the one dishonest thing available here.
class CartonCodeView extends StatelessWidget {
  final String gs1;
  final double size;
  final bool showPayload;

  const CartonCodeView({
    super.key,
    required this.gs1,
    this.size = 180,
    this.showPayload = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    final fields = GS1Barcode.parse(gs1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.line),
          ),
          child: QrImageView(
            data: gs1,
            version: QrVersions.auto,
            size: size,
            backgroundColor: Colors.white,
            padding: EdgeInsets.zero,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'QR standing in for the carton DataMatrix',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: c.inkFaint, height: 1.3),
        ),
        if (showPayload) ...[
          const SizedBox(height: 8),
          if (fields != null)
            Text(
              '(01) ${fields.gtin}   (10) ${fields.batch}\n'
              '(17) ${fields.expiry}   (21) ${fields.serial}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback,
                fontSize: 10,
                color: c.inkMuted,
                height: 1.5,
              ),
            ),
        ],
      ],
    );
  }
}
