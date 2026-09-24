import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lamp_flutter/main.dart';
import 'package:lamp_flutter/core/auth/auth_controller.dart';
import 'package:lamp_flutter/core/state/lamp_state.dart';
import 'package:lamp_flutter/core/state/theme_controller.dart';
import 'package:lamp_flutter/features/splash/splash_screen.dart';

Widget _app() => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LaMPState()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => AuthController()),
      ],
      child: const LaMPApp(),
    );

Future<void> _enterPin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.widgetWithText(TextButton, d));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // There are no platform channels under the test binding. Without this the
    // store throws MissingPluginException and every launch silently reseeds.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('launches into sign-in, offering every account', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Sign in to LaMP'), findsOneWidget);
    expect(find.text('Kamrul Hasan'), findsOneWidget);
    expect(find.text('Abdur Rahman'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Supervision'), 200);
    expect(find.text('Supervision'), findsOneWidget);
  });

  testWidgets('first sign-in sets a PIN and opens that account\'s own seat',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kamrul Hasan'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a 4-digit PIN'), findsOneWidget);

    await _enterPin(tester, '2468');
    expect(find.text('Enter it again to confirm'), findsOneWidget);
    await _enterPin(tester, '2468');

    // The delivery officer's seat, with no way back to a picker.
    expect(find.text('Delivery officer'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('a wrong PIN does not sign in', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    final auth = tester.element(find.byType(MainShell)).read<AuthController>();

    // Set a PIN, then sign out.
    await tester.tap(find.text('Kamrul Hasan'));
    await tester.pumpAndSettle();
    await _enterPin(tester, '1357');
    await _enterPin(tester, '1357');
    await auth.signOut();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kamrul Hasan'));
    await tester.pumpAndSettle();
    await _enterPin(tester, '0000');

    expect(auth.current, isNull);
    expect(find.text('Wrong PIN. Try again.'), findsOneWidget);
  });

  testWidgets('a fast load never flashes the splash', (tester) async {
    await tester.pumpWidget(_app());

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
    expect(find.text('Sign in to LaMP'), findsOneWidget);
  });
}
