import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lamp_flutter/main.dart';
import 'package:lamp_flutter/core/state/lamp_state.dart';
import 'package:lamp_flutter/core/state/theme_controller.dart';

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
}

