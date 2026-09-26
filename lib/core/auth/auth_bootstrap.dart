import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import 'auth_service.dart';
import 'firebase_auth_service.dart';
import 'local_auth_service.dart';

/// Starts Firebase and returns the sign-in backend the app runs on.
///
/// In a debug build with no Firebase project configured yet, this falls back
/// to [LocalAuthService] so the screens can still be worked on. That stand-in
/// accepts one fixed code and keeps everything on the device, so it must never
/// be reachable in a release build: there a failure to start Firebase is
/// rethrown and the app does not run, rather than signing people in on a fake.
Future<AuthService> createAuthService() async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    return FirebaseAuthService();
  } catch (e) {
    if (kReleaseMode) rethrow;
    debugPrint('Firebase is not available ($e). Using the local sign-in stand-in.');
    return LocalAuthService();
  }
}
