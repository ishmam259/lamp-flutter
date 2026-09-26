import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/domain_models.dart';
import '../state/lamp_state.dart';
import 'accounts.dart';
import 'auth_service.dart';
import 'local_auth_service.dart';
import 'user_profile.dart';

/// Who is signed in, and which seat that opens.
///
/// Sign-in itself belongs to an [AuthService] (Firebase in the app, a local
/// stand-in in tests). This class turns "who they are" plus "what they
/// registered for" into the [Account] the shell shows, so `main.dart` and the
/// seats only ever read [current].
///
/// Separate from [LaMPState] on purpose: resetting the demo world must not
/// sign anyone out.
class AuthController extends ChangeNotifier {
  final AuthService _service;
  StreamSubscription<AuthUser?>? _sub;

  AuthUser? _user;
  UserProfile? _profile;

  /// Testing only (see `kDemoTools`): a seat opened without signing in, so one
  /// phone can walk the whole flow.
  Account? _override;

  bool _loaded = false;
  bool _profileFailed = false;

  /// True from the moment a person is signed in until we know whether they
  /// have a seat. Without it "signed in, no profile yet" cannot be told apart
  /// from "signed in, and there really is no profile", and a registered person
  /// is shown the registration page while their profile is still on its way.
  bool _resolving = false;

  /// Bumped on every session change so a slow profile load from an earlier
  /// session cannot overwrite a newer one.
  int _generation = 0;

  AuthController({AuthService? service}) : _service = service ?? LocalAuthService() {
    _sub = _service.userChanges.listen(_onUser);
  }

  /// The seat to show, or null when nobody is signed in or the person still
  /// has to register.
  Account? get current => _override ?? _profile?.toAccount();

  /// The signed-in person, registered or not.
  AuthUser? get user => _user;

  /// False until the stored session has been read, so the app does not flash
  /// the sign-in screen at someone who is already signed in.
  bool get isLoaded => _loaded;

  /// Signed in, and we are still finding out which seat they hold. Show a
  /// waiting state, never the registration page.
  bool get resolvingProfile => _override == null && _user != null && _resolving;

  /// Signed in, the lookup is finished, and they have no seat: registration.
  bool get needsRegistration =>
      _override == null &&
      _user != null &&
      !_resolving &&
      _profile == null &&
      !_profileFailed;

  /// Signed in, but their registration could not be read (offline, usually).
  /// Registering again would be wrong; retry instead.
  bool get profileUnavailable =>
      _override == null && _user != null && !_resolving && _profileFailed;

  Future<void> _onUser(AuthUser? user) async {
    final generation = ++_generation;
    _user = user;
    _profile = null;
    _profileFailed = false;
    if (user == null) {
      _resolving = false;
      _loaded = true;
      notifyListeners();
      return;
    }
    _resolving = true;
    // Tell the screen now, so it can show "signing you in" rather than
    // whatever it happened to be showing.
    notifyListeners();
    await _loadProfile(user, generation);
  }

  Future<void> _loadProfile(AuthUser user, int generation) async {
    UserProfile? profile;
    var failed = false;
    try {
      profile = await _service.loadProfile(user.uid);
    } catch (e) {
      debugPrint('AuthController: could not read the profile ($e)');
      failed = true;
    }
    if (generation != _generation) return;
    _profile = profile;
    _profileFailed = failed;
    _resolving = false;
    _loaded = true;
    notifyListeners();
  }

  /// Try again after [profileUnavailable].
  Future<void> retryProfile() async {
    final user = _user;
    if (user == null) return;
    _profileFailed = false;
    _resolving = true;
    notifyListeners();
    await _loadProfile(user, ++_generation);
  }

  /// Google account picker. Throws [AuthFailure]; a dismissed picker throws
  /// [AuthFailureKind.cancelled], which callers should not show as an error.
  Future<void> signInWithGoogle() => _service.signInWithGoogle();

  Future<PhoneChallenge> sendPhoneCode(String phone) => _service.sendPhoneCode(phone);

  Future<void> confirmPhoneCode(PhoneChallenge challenge, String code) =>
      _service.confirmPhoneCode(challenge, code);

  /// Finish registration: record which seat this person holds.
  Future<void> register({
    required String name,
    required PersonaId seat,
    String? pharmacyDid,
    String? mpoId,
    Msp? bank,
  }) async {
    final user = _user;
    if (user == null) throw AuthFailure.of(AuthFailureKind.other);
    final profile = UserProfile(
      uid: user.uid,
      name: name.trim().isEmpty ? user.suggestedName : name.trim(),
      seat: seat,
      pharmacyDid: pharmacyDid,
      mpoId: mpoId,
      bank: bank,
      phone: user.phone,
      email: user.email,
    );
    await _service.saveProfile(profile);
    _profile = profile;
    notifyListeners();
  }

  /// True when this person holds a seat they registered for and can give up.
  bool get canReleaseSeat => _override == null && _profile != null;

  /// Give up this person's seat, so someone else can register for it. They stay
  /// signed in and land on registration again. Throws [AuthFailure].
  Future<void> releaseSeat() async {
    final profile = _profile;
    if (profile == null) return;
    await _service.releaseSeat(profile);
    _profile = null;
    _profileFailed = false;
    notifyListeners();
  }

  /// Testing only (see `kDemoTools`): open another account's seat without
  /// signing in as it.
  Future<void> switchTo(Account a) async {
    _override = a;
    notifyListeners();
  }

  Future<void> signOut() async {
    // Forget the person at once, not when the provider gets round to telling
    // us. While `_user` outlived `_profile` the app read "signed in, no seat"
    // and flashed the registration page on the way to sign-in. Bumping the
    // generation also stops a profile load still in flight from bringing the
    // old session back.
    _generation++;
    _override = null;
    _user = null;
    _profile = null;
    _profileFailed = false;
    _resolving = false;
    notifyListeners();
    try {
      await _service.signOut();
    } catch (e) {
      debugPrint('AuthController: could not sign out ($e)');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
