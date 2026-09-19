import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      // Push it to the platform too. A preference stored before this existed
      // has never been seen by the system, so the launch screen would keep
      // disagreeing with the app until the toggle was touched again.
      await _syncPlatformNightMode(_mode);
    } catch (e) {
      // Storage unavailable is not an error worth surfacing — the app simply
      // follows the system until the next launch.
      debugPrint('ThemeController: could not read the stored mode ($e)');
    }
  }

  /// Tells the platform which night mode this app runs in.
  ///
  /// The launch screen is composed by the system before any app code runs, so
  /// it cannot read a preference stored inside the app. Handing the choice to
  /// the platform is what lets the *next* cold start draw a launch screen that
  /// matches — otherwise a phone in light mode shows a white launch screen and
  /// then a dark app.
  static const MethodChannel _platform = MethodChannel('lamp/uimode');

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

    await _syncPlatformNightMode(mode);
  }

  Future<void> _syncPlatformNightMode(ThemeMode mode) async {
    try {
      await _platform.invokeMethod<bool>('setNightMode', {'mode': mode.name});
    } on MissingPluginException {
      // iOS, web and the test binding have no such channel. The launch screen
      // there already adapts on its own, so there is nothing to keep in step.
    } catch (e) {
      debugPrint('ThemeController: platform night mode not set ($e)');
    }
  }

  /// Step through system → light → dark → system.
  ///
  /// A three-state cycle rather than a two-state switch, because "follow the
  /// phone" is a real choice and a plain toggle silently discards it the first
  /// time someone taps.
  ///
  /// The starting mode is captured before `set()` mutates it. Two rapid
  /// `cycle()` calls in the same frame both used to read the just-written
  /// mode and advance by two steps; capturing first keeps each tap at one
  /// step regardless of how quickly they land.
  Future<void> cycle() {
    final start = _mode;
    return set(switch (start) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    });
  }

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
