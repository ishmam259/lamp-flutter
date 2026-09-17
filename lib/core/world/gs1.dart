// GS1 DataMatrix string parsing and generation.
// Elements: (01) GTIN-14, (17) Expiry YYMMDD, (10) Batch, (21) Serial.

class GS1Barcode {
  final String gtin;
  final String expiry;
  final String batch;
  final String serial;

  const GS1Barcode({
    required this.gtin,
    required this.expiry,
    required this.batch,
    required this.serial,
  });

  String get encoded => '(01)$gtin(17)$expiry(10)$batch(21)$serial';

  static String makeGtin(String prefix12) {
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      final digit = int.parse(prefix12[i]);
      sum += (i % 2 == 0) ? digit * 3 : digit;
    }
    final check = (10 - (sum % 10)) % 10;
    return '0$prefix12$check';
  }

  static String encodeGs1({
    required String gtin,
    required String expiry,
    required String batch,
    required String serial,
  }) {
    return '(01)$gtin(17)$expiry(10)$batch(21)$serial';
  }

  static GS1Barcode? parse(String raw) {
    try {
      final gtinMatch = RegExp(r'\(01\)(\d{14})').firstMatch(raw);
      final expiryMatch = RegExp(r'\(17\)(\d{6})').firstMatch(raw);
      final batchMatch = RegExp(r'\(10\)([A-Za-z0-9\-]+)').firstMatch(raw);
      final serialMatch = RegExp(r'\(21\)([A-Za-z0-9\-]+)').firstMatch(raw);

      if (gtinMatch != null && expiryMatch != null && batchMatch != null && serialMatch != null) {
        return GS1Barcode(
          gtin: gtinMatch.group(1)!,
          expiry: expiryMatch.group(1)!,
          batch: batchMatch.group(1)!,
          serial: serialMatch.group(1)!,
        );
      }
    } catch (_) {}
    return null;
  }
}
