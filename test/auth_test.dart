import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lamp_flutter/core/auth/auth_controller.dart';
import 'package:lamp_flutter/core/auth/auth_service.dart';
import 'package:lamp_flutter/core/auth/local_auth_service.dart';
import 'package:lamp_flutter/core/auth/phone_number.dart';
import 'package:lamp_flutter/core/auth/user_profile.dart';
import 'package:lamp_flutter/core/models/domain_models.dart';
import 'package:lamp_flutter/core/state/lamp_state.dart';
import 'package:lamp_flutter/core/world/seed.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('normalizePhone', () {
    test('accepts the ways a Bangladeshi number is written', () {
      for (final raw in [
        '01711204488',
        '01711 204488',
        '01711-204488',
        '1711204488',
        '8801711204488',
        '+8801711204488',
        '+880 1711 204488',
      ]) {
        expect(normalizePhone(raw), '+8801711204488', reason: raw);
      }
    });

    test('keeps another country\'s international number as it is', () {
      expect(normalizePhone('+14155550123'), '+14155550123');
    });

    test('refuses what cannot be a mobile number', () {
      for (final raw in ['', '   ', '12345', '0171120448', 'abc', '01011204488']) {
        expect(normalizePhone(raw), isNull, reason: '"$raw"');
      }
    });

    test('formats for display', () {
      expect(formatPhone('+8801711204488'), '+880 1711 204488');
      expect(formatPhone('+14155550123'), '+14155550123');
    });
  });

  group('LocalAuthService', () {
    test('sends a code to a well-formed number and refuses a malformed one',
        () async {
      final s = LocalAuthService();
      final c = await s.sendPhoneCode('+8801711204488');
      expect(c.phone, '+8801711204488');
      expect(
        () => s.sendPhoneCode('01711204488'),
        throwsA(isA<AuthFailure>()
            .having((f) => f.kind, 'kind', AuthFailureKind.invalidPhone)),
      );
    });

    test('accepts only the test code', () async {
      final s = LocalAuthService();
      final c = await s.sendPhoneCode('+8801711204488');
      expect(
        () => s.confirmPhoneCode(c, '111111'),
        throwsA(isA<AuthFailure>()
            .having((f) => f.kind, 'kind', AuthFailureKind.invalidCode)),
      );
      final user = await s.confirmPhoneCode(c, LocalAuthService.testCode);
      expect(user.phone, '+8801711204488');
    });

    test('the same number is the same person every time', () async {
      final s = LocalAuthService();
      final a = await s.confirmPhoneCode(
          await s.sendPhoneCode('+8801711204488'), LocalAuthService.testCode);
      final b = await s.confirmPhoneCode(
          await s.sendPhoneCode('+8801711204488'), LocalAuthService.testCode);
      expect(a.uid, b.uid);
    });

    test('one pharmacy cannot be claimed by two people', () async {
      final s = LocalAuthService();
      final did = SeedData.pharmacies.first.did;
      await s.saveProfile(UserProfile(
          uid: 'a', name: 'A', seat: PersonaId.pharmacy, pharmacyDid: did));
      expect(
        () => s.saveProfile(UserProfile(
            uid: 'b', name: 'B', seat: PersonaId.pharmacy, pharmacyDid: did)),
        throwsA(isA<AuthFailure>()
            .having((f) => f.kind, 'kind', AuthFailureKind.seatTaken)),
      );
      // The same person registering again is not a clash with themselves.
      await s.saveProfile(UserProfile(
          uid: 'a', name: 'A2', seat: PersonaId.pharmacy, pharmacyDid: did));
    });

    test('a desk seat can be shared', () async {
      final s = LocalAuthService();
      for (final uid in ['a', 'b']) {
        await s.saveProfile(UserProfile(
            uid: uid, name: uid, seat: PersonaId.bank, bank: Msp.meghnaMSP));
      }
      expect(await s.loadProfile('a'), isNotNull);
      expect(await s.loadProfile('b'), isNotNull);
    });
  });

  group('UserProfile', () {
    test('survives a round trip through JSON', () {
      final p = UserProfile(
        uid: 'u1',
        name: 'Rina',
        seat: PersonaId.bank,
        bank: Msp.padmaMSP,
        phone: '+8801711204488',
      );
      final back = UserProfile.fromJson('u1', p.toJson());
      expect(back.seat, PersonaId.bank);
      expect(back.bank, Msp.padmaMSP);
      expect(back.phone, '+8801711204488');
      expect(back.name, 'Rina');
    });

    test('opens the seat it was registered for', () {
      final pharmacy = SeedData.pharmacies[2];
      final account = UserProfile(
        uid: 'u2',
        name: 'Owner',
        seat: PersonaId.pharmacy,
        pharmacyDid: pharmacy.did,
      ).toAccount();
      expect(account.seat, PersonaId.pharmacy);
      expect(account.pharmacyDid, pharmacy.did);
      expect(account.org, pharmacy.name);
    });

    test('every seeded pharmacy and round gets its own claim id, named as the rules expect',
        () {
      // firestore.rules builds the claim id from the last segment of the
      // pharmacy's did (and from the round's id). If this format changes, the
      // rules must change with it, or registration is refused.
      final ids = <String>[];
      for (final p in SeedData.pharmacies) {
        final id = UserProfile(
          uid: 'x',
          name: 'x',
          seat: PersonaId.pharmacy,
          pharmacyDid: p.did,
        ).claimId;
        expect(id, 'pharmacy-${p.did.split(':').last}', reason: p.did);
        ids.add(id!);
      }
      for (final m in SeedData.mpos) {
        final id = UserProfile(
          uid: 'x',
          name: 'x',
          seat: PersonaId.mpo,
          mpoId: m.id,
        ).claimId;
        expect(id, 'mpo-${m.id}');
        ids.add(id!);
      }
      expect(ids.toSet().length, ids.length, reason: 'two seats share a claim id');
    });

    test('only a pharmacy and a delivery round are exclusive', () {
      UserProfile p(PersonaId s, {String? pharmacy, String? mpo}) => UserProfile(
          uid: 'x', name: 'x', seat: s, pharmacyDid: pharmacy, mpoId: mpo);
      expect(p(PersonaId.pharmacy, pharmacy: 'did:lamp:ph-1').claimId, isNotNull);
      expect(p(PersonaId.mpo, mpo: 'mpo-1').claimId, isNotNull);
      expect(p(PersonaId.bank).claimId, isNull);
      expect(p(PersonaId.manufacturer).claimId, isNull);
      expect(p(PersonaId.regulator).claimId, isNull);
    });
  });

  group('AuthController', () {
    Future<AuthController> signedIn(LocalAuthService service) async {
      final auth = AuthController(service: service);
      final c = await auth.sendPhoneCode('+8801711204488');
      await auth.confirmPhoneCode(c, LocalAuthService.testCode);
      await Future<void>.delayed(Duration.zero);
      return auth;
    }

    test('signed in but unregistered needs registration, with no seat', () async {
      final auth = await signedIn(LocalAuthService());
      expect(auth.user, isNotNull);
      expect(auth.needsRegistration, isTrue);
      expect(auth.current, isNull);
    });

    test('registering opens the seat', () async {
      final auth = await signedIn(LocalAuthService());
      await auth.register(name: 'Rina', seat: PersonaId.regulator);
      expect(auth.needsRegistration, isFalse);
      expect(auth.current!.seat, PersonaId.regulator);
      expect(auth.current!.name, 'Rina');
    });

    test('a blank name falls back to what the provider knows', () async {
      final auth = AuthController(service: LocalAuthService());
      await auth.signInWithGoogle();
      await Future<void>.delayed(Duration.zero);
      await auth.register(name: '   ', seat: PersonaId.manufacturer);
      expect(auth.current!.name, 'Demo User');
    });

    test('the session and the registration survive a restart', () async {
      final first = await signedIn(LocalAuthService());
      await first.register(name: 'Rina', seat: PersonaId.regulator);

      // A new controller over the same storage: no sign-in, no registration.
      final second = AuthController(service: LocalAuthService());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(second.isLoaded, isTrue);
      expect(second.current!.seat, PersonaId.regulator);
      expect(second.needsRegistration, isFalse);
    });

    test('signing out clears the seat and the session', () async {
      final auth = await signedIn(LocalAuthService());
      await auth.register(name: 'Rina', seat: PersonaId.regulator);
      await auth.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(auth.current, isNull);
      expect(auth.user, isNull);

      final again = AuthController(service: LocalAuthService());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(again.current, isNull);
    });

    test('a profile that cannot be read is not treated as unregistered', () async {
      final auth = AuthController(service: _OfflineProfiles());
      await auth.signInWithGoogle();
      await Future<void>.delayed(Duration.zero);
      // Sending them to registration would let a returning user overwrite
      // their own seat; they should be asked to retry instead.
      expect(auth.profileUnavailable, isTrue);
      expect(auth.needsRegistration, isFalse);
    });

    test('a registered person is never offered registration while their profile loads',
        () async {
      // Register on a normal service so a profile exists in storage.
      final first = await signedIn(LocalAuthService());
      await first.register(name: 'Rina', seat: PersonaId.regulator);

      // Now sign in again where the profile lookup is held open.
      final service = _HeldProfiles();
      final auth = AuthController(service: service);
      final seen = <bool>[];
      auth.addListener(() => seen.add(auth.needsRegistration));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(auth.resolvingProfile, isTrue, reason: 'the restored session is being checked');
      expect(auth.needsRegistration, isFalse);
      expect(auth.current, isNull);

      service.release();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(auth.resolvingProfile, isFalse);
      expect(auth.current!.seat, PersonaId.regulator);
      expect(seen, isNot(contains(true)),
          reason: 'registration must never show for someone who is registered');
    });

    test('a new person is offered registration once the lookup finds nothing',
        () async {
      final service = _HeldProfiles();
      final auth = AuthController(service: service);
      await auth.signInWithGoogle();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(auth.resolvingProfile, isTrue);
      expect(auth.needsRegistration, isFalse);

      service.release();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(auth.resolvingProfile, isFalse);
      expect(auth.needsRegistration, isTrue);
    });

    test('signing out never passes through the registration page', () async {
      final auth = await signedIn(LocalAuthService());
      await auth.register(name: 'Rina', seat: PersonaId.regulator);

      final seen = <bool>[];
      auth.addListener(() => seen.add(auth.needsRegistration));
      final done = auth.signOut();

      // The person is gone at once, not when the provider reports it.
      expect(auth.user, isNull);
      expect(auth.needsRegistration, isFalse);
      await done;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(seen, isNot(contains(true)));
      expect(auth.current, isNull);
    });

    test('a profile still loading when someone signs out cannot bring them back',
        () async {
      final service = _HeldProfiles();
      final auth = AuthController(service: service);
      await auth.signInWithGoogle();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(auth.resolvingProfile, isTrue);

      await auth.signOut();
      service.release();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(auth.user, isNull);
      expect(auth.current, isNull);
      expect(auth.needsRegistration, isFalse);
    });

    test('the testing override opens a seat without signing in', () async {
      final auth = AuthController(service: LocalAuthService());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(auth.current, isNull);
      await auth.switchTo(
        UserProfile(uid: 'demo', name: 'Demo', seat: PersonaId.regulator).toAccount(),
      );
      expect(auth.current!.seat, PersonaId.regulator);
    });
  });
}

/// A backend whose profile lookup waits until the test lets it through, so the
/// moment between "signed in" and "we know your seat" can be looked at.
class _HeldProfiles extends LocalAuthService {
  final Completer<void> _gate = Completer<void>();

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<UserProfile?> loadProfile(String uid) async {
    await _gate.future;
    return super.loadProfile(uid);
  }
}

/// A backend whose profile lookup fails, as it does with no connection.
class _OfflineProfiles extends LocalAuthService {
  @override
  Future<UserProfile?> loadProfile(String uid) =>
      Future.error(const AuthFailure(AuthFailureKind.network, 'offline'));
}
