import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;

class LaMPCrypto {
  static String sha256Hex(String input) {
    final bytes = utf8.encode(input);
    final digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  /// Hash of arbitrary bytes — used for the invoice PDF (and any future
  /// binary document) where utf-8 encoding the input is wrong.
  static String sha256HexBytes(Uint8List bytes) {
    final digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  /// Canonical JSON stringify matching TS implementation
  /// Ensures key ordering is deterministic so identical objects always hash to identical digests.
  static String canonicalJson(dynamic value) {
    if (value == null) return 'null';
    if (value is num || value is bool || value is String) {
      return jsonEncode(value);
    }
    if (value is List) {
      return '[${value.map(canonicalJson).join(',')}]';
    }
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      final entries = keys.map((k) {
        final v = value[k];
        return '${jsonEncode(k)}:${canonicalJson(v)}';
      }).join(',');
      return '{$entries}';
    }
    return jsonEncode(value.toString());
  }

  static String hashOf(dynamic value) {
    return sha256Hex(canonicalJson(value));
  }
}
