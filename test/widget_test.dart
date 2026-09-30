import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lamp_flutter/main.dart';
import 'package:lamp_flutter/core/auth/auth_controller.dart';
import 'package:lamp_flutter/core/auth/local_auth_service.dart';
import 'package:lamp_flutter/core/auth/user_profile.dart';
import 'package:lamp_flutter/core/state/lamp_state.dart';
import 'package:lamp_flutter/core/state/theme_controller.dart';
import 'package:lamp_flutter/core/world/seed.dart';
import 'package:lamp_flutter/features/splash/splash_screen.dart';

Widget _app(LocalAuthService service) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LaMPState()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => AuthController(service: service)),
      ],
      child: const LaMPApp(),
    );

/// A local backend whose profile lookup waits until the test lets it through,
/// so the moment between "signed in" and "we know your seat" can be looked at.
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

AuthController _auth(WidgetTester tester) =>
    tester.element(find.byType(MainShell)).read<AuthController>();

Future<void> _signInWithPhone(WidgetTester tester, String number,
    {String code = LocalAuthService.testCode}) async {
  await tester.tap(find.byKey(const ValueKey('use-phone')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('phone-field')), number);
  await tester.tap(find.byKey(const ValueKey('send-code')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('code-field')), code);
  await tester.pumpAndSettle();
}

/// Registration is a long list on a short test screen: bring a control into
/// view before tapping it, as a person would scroll.
Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key)).last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, String field, String item) async {
  await tester.ensureVisible(find.byKey(ValueKey(field)));
  await tester.tap(find.byKey(ValueKey(field)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

/// A delivery round, as the registration dropdown lists it.
final String _round =
    '${SeedData.mpos.first.name} · ${SeedData.mpos.first.territory}';

Future<void> _register(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('register')).last);
  await tester.tap(find.byKey(const ValueKey('register')).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // There are no platform channels under the test binding. Without this the
    // store throws MissingPluginException and every launch silently reseeds.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('launches into sign-in, offering Google and a phone number',
      (tester) async {
    await tester.pumpWidget(_app(LocalAuthService()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to LaMP'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Use my phone number'), findsOneWidget);
  });

  testWidgets('a new person registers as a delivery officer and lands on that seat',
      (tester) async {
    await tester.pumpWidget(_app(LocalAuthService()));
    await tester.pumpAndSettle();

    await _signInWithPhone(tester, '01711 204488');

    // Signed in, but no seat yet: registration asks for one.
    expect(find.text('Finish registering'), findsOneWidget);
    await _tapKey(tester, 'role-mpo');
    final officer = SeedData.mpos.first;
    await _pick(tester, 'mpo-field', '${officer.name} · ${officer.territory}');
    await _register(tester);

    // The delivery officer's seat, with no way back to a sign-in list.
    expect(find.text('Delivery officer'), findsWidgets);
    expect(find.text('Finish registering'), findsNothing);
    expect(find.byTooltip('Back'), findsNothing);
    expect(_auth(tester).current!.mpoId, officer.id);
  });

  testWidgets('a wrong code does not sign in, and says so plainly',
      (tester) async {
    await tester.pumpWidget(_app(LocalAuthService()));
    await tester.pumpAndSettle();

    await _signInWithPhone(tester, '01711204488', code: '000000');

    expect(_auth(tester).user, isNull);
    expect(find.text("That code isn't right. Check it and try again."),
        findsOneWidget);
    expect(find.text('Enter the code'), findsOneWidget);
  });

  testWidgets('a number that cannot be a mobile number is refused before sending',
      (tester) async {
    await tester.pumpWidget(_app(LocalAuthService()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('use-phone')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('phone-field')), '12345');
    await tester.tap(find.byKey(const ValueKey('send-code')));
    await tester.pumpAndSettle();

    expect(find.text("That doesn't look like a valid mobile number."),
        findsOneWidget);
    expect(find.text('Enter the code'), findsNothing);
  });

  testWidgets('someone who has registered before goes straight to their seat',
      (tester) async {
    final service = LocalAuthService();
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    // Register once, as a delivery officer.
    await _signInWithPhone(tester, '01711204488');
    await _tapKey(tester, 'role-mpo');
    await _pick(tester, 'mpo-field', _round);
    await _register(tester);
    expect(_auth(tester).current, isNotNull);

    // Sign out, then sign in again with the same number.
    await _auth(tester).signOut();
    await tester.pumpAndSettle();
    expect(find.text('Welcome to LaMP'), findsOneWidget);

    await _signInWithPhone(tester, '01711204488');

    expect(find.text('Finish registering'), findsNothing);
    expect(_auth(tester).current, isNotNull);
  });

  testWidgets('Google sign-in reaches the same registration', (tester) async {
    await tester.pumpWidget(_app(LocalAuthService()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('google')));
    await tester.pumpAndSettle();

    expect(find.text('Finish registering'), findsOneWidget);
    // The name is offered from the Google account.
    expect(find.widgetWithText(TextField, 'Demo User'), findsOneWidget);
  });

  testWidgets('a registered person sees a waiting state, never registration, while signing in',
      (tester) async {
    final service = _HeldProfiles();
    // This Google account already has a seat.
    await service.saveProfile(UserProfile(
      uid: 'local-google',
      name: 'Demo User',
      seat: PersonaId.regulator,
    ));
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('google')));
    await tester.pump();
    // Past the screen's cross-fade, so the welcome page has really gone. The
    // spinner never settles, so step time rather than pumpAndSettle.
    await tester.pump(const Duration(milliseconds: 400));

    // Signed in, profile still on its way.
    expect(find.text('Signing you in…'), findsOneWidget);
    expect(find.text('Finish registering'), findsNothing);
    expect(find.text('Welcome to LaMP'), findsNothing);

    service.release();
    await tester.pumpAndSettle();

    expect(_auth(tester).current!.seat, PersonaId.regulator);
    expect(find.text('Finish registering'), findsNothing);
    expect(find.text('Signing you in…'), findsNothing);
  });

  testWidgets('signing out goes straight to sign-in, not through registration',
      (tester) async {
    final service = LocalAuthService();
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('google')));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'role-mpo');
    await _pick(tester, 'mpo-field', _round);
    await _register(tester);
    expect(_auth(tester).current, isNotNull);

    final signOut = _auth(tester).signOut();
    // The very next frame must already be past the seat, and must not be the
    // registration page.
    await tester.pump();
    expect(find.text('Finish registering'), findsNothing);
    await signOut;
    await tester.pumpAndSettle();

    expect(find.text('Finish registering'), findsNothing);
    expect(find.text('Welcome to LaMP'), findsOneWidget);
  });

  testWidgets('bank, manufacturer and regulator cannot be self-registered',
      (tester) async {
    await tester.pumpWidget(_app(LocalAuthService()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('google')));
    await tester.pumpAndSettle();

    for (final desk in ['role-bank', 'role-manufacturer', 'role-regulator']) {
      await _tapKey(tester, desk);
    }
    // None of them took: nothing is selected, so Register stays off.
    final register = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('register')).last,
    );
    expect(register.onPressed, isNull);
    expect(find.text('Set up by your administrator'), findsNWidgets(3));
  });

  testWidgets('two people cannot hold the same pharmacy', (tester) async {
    final service = LocalAuthService();
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    final pharmacy = SeedData.pharmacies.first;
    final label = '${pharmacy.name} · ${pharmacy.territory}';

    // The first owner takes it.
    await _signInWithPhone(tester, '01711204488');
    await _tapKey(tester, 'role-pharmacy');
    await _pick(tester, 'pharmacy-field', label);
    await _register(tester);
    await _auth(tester).signOut();
    await tester.pumpAndSettle();

    // A second person tries for the same one.
    await _signInWithPhone(tester, '01811204488');
    await _tapKey(tester, 'role-pharmacy');
    await _pick(tester, 'pharmacy-field', label);
    await _register(tester);

    expect(_auth(tester).current, isNull);
    expect(
      find.textContaining('Someone else has already registered'),
      findsOneWidget,
    );
  });

  testWidgets('a fast load never flashes the splash', (tester) async {
    await tester.pumpWidget(_app(LocalAuthService()));

    // Before the show-delay elapses there must be nothing to see. Platform
    // guidance on both sides is that a launch screen should disappear as soon
    // as possible; a splash that appears for eighty milliseconds and vanishes
    // reads as a glitch, and its entrance animation is caught mid-flight.
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byType(SplashScreen),
      findsNothing,
      reason: 'the splash appeared before the show-delay had elapsed',
    );

    // And it still arrives at the app.
    await tester.pumpAndSettle();
    expect(find.text('Welcome to LaMP'), findsOneWidget);
  });
}
