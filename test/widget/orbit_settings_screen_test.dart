import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/orbit/features/settings/orbit_settings_screen.dart';

void main() {
  testWidgets('placement controls are removed and core settings remain', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: OrbitSettingsScreen())),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Placement'), findsNothing);
    expect(find.textContaining('Vertical offset'), findsNothing);
    expect(find.textContaining('Horizontal offset'), findsNothing);
    expect(find.textContaining('Compact width'), findsNothing);
    expect(find.textContaining('Compact height'), findsNothing);

    expect(find.text('Enable overlay'), findsOneWidget);
    expect(find.text('Reduced motion'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Manage app filters'), 240);
    expect(find.text('Manage app filters'), findsOneWidget);
  });
}
