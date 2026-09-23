import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../chain/crypto.dart';
import 'accounts.dart';

/// Who is signed in, and the PIN check that gets them there.
///
/// On-device for now: each account's PIN is set the first time it signs in on
/// this phone and stored only as a salted hash. The session survives a
/// restart. The screens only ever call [signIn], [createPin] and [signOut],
/// so a server-backed check can replace this class without touching them.
///
/// Separate from [LaMPState] on purpose: resetting the demo world must not
/// sign anyone out.
class AuthController extends ChangeNotifier {
  static const String _sessionKey = 'lamp.session';
  static const String _pinPrefix = 'lamp.pin.';

  /// Wrong PINs allowed before sign-in pauses.
  static const int maxAttempts = 5;
  static const Duration lockout = Duration(seconds: 30);

  static const int pinLength = 4;

  Account? _current;
  Account? get current => _current;

  bool _loaded = false;

  /// False until the stored session has been read, so the app does not flash
  /// the sign-in screen at someone who is already signed in.
  bool get isLoaded => _loaded;

  final Map<String, String> _pinHashes = {};
  int _failures = 0;
  DateTime? _lockedUntil;

  AuthController() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final a in Accounts.all) {
        final h = prefs.getString('$_pinPrefix${a.id}');
        if (h != null) _pinHashes[a.id] = h;
      }
      _current = Accounts.byId(prefs.getString(_sessionKey));
    } catch (e) {
      debugPrint('AuthController: could not read the session ($e)');
    }
    _loaded = true;
    notifyListeners();
  }

  bool hasPin(Account a) => _pinHashes.containsKey(a.id);

  /// How long sign-in is paused after too many wrong PINs, or null.
  Duration? get lockedFor {
    final until = _lockedUntil;
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  static String _hash(Account a, String pin) =>
      LaMPCrypto.sha256Hex('lamp-pin:v1:${a.id}:$pin');

  /// First sign-in on this phone: store the PIN and sign in.
  Future<void> createPin(Account a, String pin) async {
    final h = _hash(a, pin);
    _pinHashes[a.id] = h;
    await _write('$_pinPrefix${a.id}', h);
    await _open(a);
  }

  /// Returns false on a wrong PIN or while sign-in is paused.
  Future<bool> signIn(Account a, String pin) async {
    if (lockedFor != null) return false;
    if (_pinHashes[a.id] != _hash(a, pin)) {
      _failures++;
      if (_failures >= maxAttempts) {
        _failures = 0;
        _lockedUntil = DateTime.now().add(lockout);
      }
      notifyListeners();
      return false;
    }
    await _open(a);
    return true;
  }

  /// Testing only (see `kDemoTools`): open another account's seat without its
  /// PIN, so one phone can walk the whole flow.
  Future<void> switchTo(Account a) => _open(a);

  Future<void> signOut() async {
    _current = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (e) {
      debugPrint('AuthController: could not clear the session ($e)');
    }
  }

  Future<void> _open(Account a) async {
    _failures = 0;
    _lockedUntil = null;
    _current = a;
    notifyListeners();
    await _write(_sessionKey, a.id);
  }

  Future<void> _write(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      debugPrint('AuthController: could not save ($e)');
    }
  }
}
