import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/orbit/features/settings/orbit_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('basic and advanced panes are available', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: OrbitSettingsScreen())),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Enable overlay'), findsOneWidget);
    expect(find.text('Reduced motion'), findsOneWidget);
    expect(find.text('Manage app filters'), findsOneWidget);

    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    expect(find.text('Placement & Depth'), findsOneWidget);
    expect(find.textContaining('Lane offset Y'), findsOneWidget);
    expect(find.textContaining('Depth emphasis'), findsOneWidget);
    expect(find.textContaining('Compact width'), findsOneWidget);
    expect(find.textContaining('Compact height'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Re-run setup wizard'), 300);
    expect(find.text('Re-run setup wizard'), findsOneWidget);
  });

  testWidgets('advanced pane can reset placement', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: OrbitSettingsScreen())),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Reset placement & depth'), 300);
    expect(find.text('Reset placement & depth'), findsOneWidget);
  });
}
