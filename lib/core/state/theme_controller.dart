import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light, dark, or whatever the phone is set to.
///
/// Separate from [LaMPState] on purpose: how the app looks is a preference
/// belonging to the person holding the phone, and it should not be thrown away
/// when the demo world is reset.
class ThemeController extends ChangeNotifier {
  static const String _key = 'lamp.themeMode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  ThemeController() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_key);
      _mode = switch (stored) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      notifyListeners();
    } catch (e) {
      // Storage unavailable is not an error worth surfacing — the app simply
      // follows the system until the next launch.
      debugPrint('ThemeController: could not read the stored mode ($e)');
    }
  }

  Future<void> set(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (e) {
      debugPrint('ThemeController: could not save the mode ($e)');
    }
  }

  /// Step through system → light → dark → system.
  ///
  /// A three-state cycle rather than a two-state switch, because "follow the
  /// phone" is a real choice and a plain toggle silently discards it the first
  /// time someone taps.
  Future<void> cycle() => set(switch (_mode) {
        ThemeMode.system => ThemeMode.light,
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.system,
      });

  IconData get icon => switch (_mode) {
        ThemeMode.system => Icons.brightness_auto_outlined,
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
      };

  String get label => switch (_mode) {
        ThemeMode.system => 'Following system',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };
}
