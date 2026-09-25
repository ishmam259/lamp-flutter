import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_service.dart';
import 'user_profile.dart';

/// Sign-in and registration on Firebase: Google or a phone number for who you
/// are, Firestore for which seat you hold.
///
/// Firestore layout (see `firestore.rules`):
///   users/{uid}       the profile: name, seat, and which pharmacy / round / bank
///   claims/{claimId}  `{uid}` marking a pharmacy or delivery round as taken
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    fb.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? google,
  })  : _auth = auth ?? fb.FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance,
        _google = google ?? GoogleSignIn.instance;

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final GoogleSignIn _google;

  bool _googleReady = false;

  /// Marks a challenge that has already signed in on its own: on Android the
  /// SMS can be read automatically and no code is ever typed.
  static const String _autoVerified = 'auto-verified';

  @override
  Stream<AuthUser?> get userChanges => _auth.authStateChanges().map(_toUser);

  static AuthUser? _toUser(fb.User? u) => u == null
      ? null
      : AuthUser(
          uid: u.uid,
          phone: u.phoneNumber,
          email: u.email,
          displayName: u.displayName,
        );

  /* ---------------------------------------------------------------------- */
  /* Google                                                                  */
  /* ---------------------------------------------------------------------- */

  Future<void> _ensureGoogle() async {
    if (_googleReady) return;
    // On Android the web client id comes from google-services.json
    // (`default_web_client_id`), so nothing is passed here.
    await _google.initialize();
    _googleReady = true;
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    try {
      await _ensureGoogle();
      final account = await _google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw AuthFailure.of(AuthFailureKind.other);
      final result = await _auth
          .signInWithCredential(fb.GoogleAuthProvider.credential(idToken: idToken));
      return _toUser(result.user)!;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw AuthFailure.of(AuthFailureKind.cancelled);
      }
      debugPrint('FirebaseAuthService: Google sign-in failed (${e.code}: ${e.description})');
      throw AuthFailure.of(AuthFailureKind.other);
    } on fb.FirebaseAuthException catch (e) {
      throw _failure(e);
    }
  }

  /* ---------------------------------------------------------------------- */
  /* Phone                                                                   */
  /* ---------------------------------------------------------------------- */

  @override
  Future<PhoneChallenge> sendPhoneCode(String phone) {
    final done = Completer<PhoneChallenge>();

    _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        // Android read the SMS itself (or the number is a test number that
        // needs no code). Sign in now; the auth stream carries the person on.
        try {
          await _auth.signInWithCredential(credential);
        } on fb.FirebaseAuthException catch (e) {
          debugPrint('FirebaseAuthService: automatic sign-in failed (${e.code})');
        }
        if (!done.isCompleted) {
          done.complete(PhoneChallenge(phone: phone, token: _autoVerified));
        }
      },
      verificationFailed: (e) {
        if (!done.isCompleted) done.completeError(_failure(e));
      },
      codeSent: (verificationId, _) {
        if (!done.isCompleted) {
          done.complete(PhoneChallenge(phone: phone, token: verificationId));
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    ).catchError((Object e) {
      if (!done.isCompleted) {
        done.completeError(e is fb.FirebaseAuthException
            ? _failure(e)
            : AuthFailure.of(AuthFailureKind.other));
      }
    });

    return done.future;
  }

  @override
  Future<AuthUser> confirmPhoneCode(PhoneChallenge challenge, String code) async {
    if (challenge.token == _autoVerified) {
      final current = _toUser(_auth.currentUser);
      if (current != null) return current;
    }
    try {
      final result = await _auth.signInWithCredential(
        fb.PhoneAuthProvider.credential(
          verificationId: challenge.token,
          smsCode: code,
        ),
      );
      return _toUser(result.user)!;
    } on fb.FirebaseAuthException catch (e) {
      throw _failure(e);
    }
  }

  /* ---------------------------------------------------------------------- */
  /* Profile                                                                 */
  /* ---------------------------------------------------------------------- */

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  DocumentReference<Map<String, dynamic>> _claim(String id) =>
      _db.collection('claims').doc(id);

  @override
  Future<UserProfile?> loadProfile(String uid) async {
    final snap = await _user(uid).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return UserProfile.fromJson(uid, data);
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    final claim = profile.claimId;
    var claimIsMine = false;

    try {
      if (claim != null) {
        final existing = await _claim(claim).get();
        if (existing.exists) {
          if (existing.data()?['uid'] != profile.uid) {
            throw AuthFailure.of(AuthFailureKind.seatTaken);
          }
          claimIsMine = true;
        }
      }

      // One batch, so a profile never exists without its claim. The rules
      // refuse a pharmacy or round profile that is not written with one.
      final batch = _db.batch();
      if (claim != null && !claimIsMine) {
        batch.set(_claim(claim), {'uid': profile.uid});
      }
      batch.set(_user(profile.uid), profile.toJson());
      await batch.commit();
    } on FirebaseException catch (e) {
      debugPrint('FirebaseAuthService: could not save the profile (${e.code})');
      if (e.code == 'unavailable') throw AuthFailure.of(AuthFailureKind.network);
      if (e.code == 'permission-denied' && claim != null) {
        // Most likely someone claimed it between our check and our write.
        try {
          final now = await _claim(claim).get();
          if (now.exists && now.data()?['uid'] != profile.uid) {
            throw AuthFailure.of(AuthFailureKind.seatTaken);
          }
        } on FirebaseException {
          // Fall through to the generic message.
        }
      }
      throw AuthFailure.of(AuthFailureKind.other);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _ensureGoogle();
      await _google.signOut();
    } catch (e) {
      // Not signed in with Google, or the plugin is unavailable: nothing to do.
      debugPrint('FirebaseAuthService: Google sign-out skipped ($e)');
    }
    await _auth.signOut();
  }

  /* ---------------------------------------------------------------------- */
  /* Errors                                                                  */
  /* ---------------------------------------------------------------------- */

  /// Firebase error codes become plain-language failures. The code itself goes
  /// to the log for developers and never to the screen.
  static AuthFailure _failure(fb.FirebaseAuthException e) {
    debugPrint('FirebaseAuthService: ${e.code} ${e.message}');
    return AuthFailure.of(switch (e.code) {
      'invalid-phone-number' || 'missing-phone-number' => AuthFailureKind.invalidPhone,
      'invalid-verification-code' || 'missing-verification-code' => AuthFailureKind.invalidCode,
      'session-expired' || 'code-expired' || 'invalid-verification-id' => AuthFailureKind.codeExpired,
      'too-many-requests' || 'quota-exceeded' => AuthFailureKind.tooManyAttempts,
      'network-request-failed' => AuthFailureKind.network,
      'web-context-cancelled' || 'popup-closed-by-user' => AuthFailureKind.cancelled,
      _ => AuthFailureKind.other,
    });
  }
}
