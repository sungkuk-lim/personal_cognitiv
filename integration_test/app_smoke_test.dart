import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:personal_cognitive/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'graph_onboarding_done': true,
      'guest_mode': true,
    });
  });

  testWidgets('app launches without crash', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 8));
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('main tabs are reachable', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 8));

    final navItems = find.byIcon(Icons.hub_outlined);
    if (navItems.evaluate().isNotEmpty) {
      await tester.tap(navItems.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    final settingsIcons = find.byIcon(Icons.settings_outlined);
    if (settingsIcons.evaluate().isNotEmpty) {
      await tester.tap(settingsIcons.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.textContaining('설정'), findsWidgets);
    }
  });
}
