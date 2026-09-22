import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lamp_flutter/main.dart';
import 'package:lamp_flutter/core/state/lamp_state.dart';
import 'package:lamp_flutter/core/state/theme_controller.dart';
import 'package:lamp_flutter/features/splash/splash_screen.dart';

void main() {
  setUp(() {
    // There are no platform channels under the test binding. Without this the
    // store throws MissingPluginException and every launch silently reseeds.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('LaMP App smoke test - launches into Persona Launcher', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LaMPState()),
          ChangeNotifierProvider(create: (_) => ThemeController()),
        ],
        child: const LaMPApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Last Mile Pharmacy'), findsOneWidget);

    // All five seats are offered, named by role rather than by the name of the
    // screen they open.
    expect(find.text('Delivery officer'), findsOneWidget);
    expect(find.text('Pharmacy'), findsOneWidget);
    expect(find.text('Manufacturer'), findsOneWidget);

    // The list builds lazily, so the last seats are not mounted until the
    // viewport reaches them.
    await tester.scrollUntilVisible(find.text('Regulator'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Bank'), findsOneWidget);
    expect(find.text('Regulator'), findsOneWidget);
  });

  testWidgets('system back returns to the launcher, it does not close the app',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LaMPState()),
          ChangeNotifierProvider(create: (_) => ThemeController()),
        ],
        child: const LaMPApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Into a seat.
    //
    // 'Delivery officer' is no longer a witness for which screen is showing:
    // the seat's own app bar is titled with the same words the launcher card
    // uses, which is the point — a seat should be called one thing. The
    // section header is what only the launcher has.
    await tester.tap(find.text('Delivery officer'));
    await tester.pumpAndSettle();
    expect(find.text('In the field'), findsNothing);

    // Seats are swapped by setState rather than pushed, so there is only ever
    // one route. Before PopScope, this popped it and closed the app.
    final popped = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(popped, isTrue, reason: 'back should have been handled, not ignored');
    expect(
      find.text('In the field'),
      findsOneWidget,
      reason: 'back from a seat should land on the launcher',
    );
  });

  testWidgets('a fast load never flashes the splash', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LaMPState()),
          ChangeNotifierProvider(create: (_) => ThemeController()),
        ],
        child: const LaMPApp(),
      ),
    );

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
    expect(find.text('Delivery officer'), findsOneWidget);
  });
}
