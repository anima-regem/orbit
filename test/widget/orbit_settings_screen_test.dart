import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/orbit/features/settings/orbit_settings_screen.dart';

void main() {
  testWidgets('placement controls and z-axis lift are available', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: OrbitSettingsScreen())),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Placement & Depth'), findsOneWidget);
    expect(find.textContaining('Vertical offset'), findsOneWidget);
    expect(find.textContaining('Horizontal offset'), findsOneWidget);
    expect(find.textContaining('Z-axis lift'), findsOneWidget);
    expect(find.textContaining('Compact width'), findsOneWidget);
    expect(find.textContaining('Compact height'), findsOneWidget);

    expect(find.text('Enable overlay'), findsOneWidget);
    expect(find.text('Reduced motion'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Manage app filters'), 240);
    expect(find.text('Manage app filters'), findsOneWidget);
  });
}
