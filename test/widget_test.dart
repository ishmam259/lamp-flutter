import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lamp_flutter/main.dart';
import 'package:lamp_flutter/core/state/lamp_state.dart';

void main() {
  setUp(() {
    // There are no platform channels under the test binding. Without this the
    // store throws MissingPluginException and every launch silently reseeds.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('LaMP App smoke test - launches into Persona Launcher', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LaMPState(),
        child: const LaMPApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Last Mile Pharmacy'), findsOneWidget);
    expect(find.text('MPO Mobile App'), findsOneWidget);
    expect(find.text('Pharmacy Owner App'), findsOneWidget);
  });
}

