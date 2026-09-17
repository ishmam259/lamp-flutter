import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Durable storage for the whole demo world.
///
/// One key holding one JSON document, rather than a key per collection: the
/// ledger, the clock and the off-chain records are only ever meaningful
/// together. A half-written world — blocks from one run, deliveries from
/// another — would be worse than no world at all, and a single key makes that
/// state unrepresentable.
///
/// Backed by SharedPreferences, which is localStorage on web and a plist or
/// XML file on the phones, so the same code persists on every target.
class LaMPStore {
  static const String _key = 'lamp.world';

  /// Bumped whenever the stored shape changes. A snapshot written by an older
  /// build is discarded and reseeded rather than half-read into the new shape.
  static const int schemaVersion = 1;

  /// Read the stored world, or null when there is nothing usable.
  ///
  /// Every failure path returns null so the caller reseeds. A corrupted store
  /// must not be able to stop the app from starting — on a demo device that
  /// would be indistinguishable from the app being broken.
  static Future<Map<String, dynamic>?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final json = Map<String, dynamic>.from(decoded);
      if (json['schemaVersion'] != schemaVersion) {
        debugPrint(
          'LaMPStore: stored schema ${json['schemaVersion']} != $schemaVersion, reseeding',
        );
        return null;
      }
      return json;
    } catch (e) {
      debugPrint('LaMPStore: could not read the stored world ($e), reseeding');
      return null;
    }
  }

  /// Write the world. Returns false when it could not be stored.
  ///
  /// A failed save is reported but never thrown: losing persistence is a
  /// degraded demo, while an exception out of an autosave would take down the
  /// screen the user is on.
  static Future<bool> save(Map<String, dynamic> world) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        ...world,
        'schemaVersion': schemaVersion,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      });
      return await prefs.setString(_key, payload);
    } catch (e) {
      debugPrint('LaMPStore: could not save the world ($e)');
      return false;
    }
  }

  /// Drop the stored world, so the next launch reseeds from scratch.
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('LaMPStore: could not clear the stored world ($e)');
    }
  }
}
