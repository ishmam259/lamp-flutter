import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'user_profile.dart';

/// A stand-in for Firebase that keeps everything on the device.
///
/// It exists so tests and offline development run without a Firebase project.
/// It behaves like Firebase's test phone numbers: any well-formed number is
/// sent a code, and the code is always [testCode]. Google sign-in returns one
/// fixed account. Nothing here is secure and nothing leaves the phone.
class LocalAuthService implements AuthService {
  static const String testCode = '123456';

  static const String _sessionKey = 'lamp.local.session';
  static const String _profilesKey = 'lamp.local.profiles';
  static const String _claimsKey = 'lamp.local.claims';

  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _user;
  bool _restored = false;

  LocalAuthService() {
    _restore();
  }

  @override
  Stream<AuthUser?> get userChanges async* {
    // A late listener must still hear the restored session.
    if (!_restored) await _restoring.future;
    yield _user;
    yield* _controller.stream;
  }

  final Completer<void> _restoring = Completer<void>();

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionKey);
      if (raw != null) _user = _userFromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('LocalAuthService: could not restore the session ($e)');
    }
    _restored = true;
    _restoring.complete();
  }

  @override
  Future<AuthUser> signInWithGoogle() async =>
      _open(const AuthUser(
        uid: 'local-google',
        email: 'demo.user@example.com',
        displayName: 'Demo User',
      ));

  @override
  Future<PhoneChallenge> sendPhoneCode(String phone) async {
    if (!RegExp(r'^\+\d{8,15}$').hasMatch(phone)) {
      throw AuthFailure.of(AuthFailureKind.invalidPhone);
    }
    return PhoneChallenge(phone: phone, token: 'local-$phone');
  }

  @override
  Future<AuthUser> confirmPhoneCode(PhoneChallenge challenge, String code) async {
    if (code != testCode) throw AuthFailure.of(AuthFailureKind.invalidCode);
    return _open(AuthUser(
      uid: 'local-phone-${challenge.phone.replaceAll('+', '')}',
      phone: challenge.phone,
    ));
  }

  @override
  Future<UserProfile?> loadProfile(String uid) async {
    final profiles = await _readMap(_profilesKey);
    final json = profiles[uid];
    if (json == null) return null;
    return UserProfile.fromJson(uid, Map<String, dynamic>.from(json as Map));
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    final claims = await _readMap(_claimsKey);
    final claim = profile.claimId;
    if (claim != null && claims[claim] != null && claims[claim] != profile.uid) {
      throw AuthFailure.of(AuthFailureKind.seatTaken);
    }
    if (claim != null) claims[claim] = profile.uid;
    final profiles = await _readMap(_profilesKey);
    profiles[profile.uid] = profile.toJson();
    await _writeMap(_claimsKey, claims);
    await _writeMap(_profilesKey, profiles);
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (e) {
      debugPrint('LocalAuthService: could not clear the session ($e)');
    }
  }

  Future<AuthUser> _open(AuthUser user) async {
    _user = user;
    _controller.add(user);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, jsonEncode({
        'uid': user.uid,
        'phone': user.phone,
        'email': user.email,
        'displayName': user.displayName,
      }));
    } catch (e) {
      debugPrint('LocalAuthService: could not save the session ($e)');
    }
    return user;
  }

  static AuthUser _userFromJson(Map<String, dynamic> j) => AuthUser(
        uid: j['uid'] as String,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        displayName: j['displayName'] as String?,
      );

  Future<Map<String, dynamic>> _readMap(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return {};
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> _writeMap(String key, Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }
}
