import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/orbit/features/home/orbit_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('renders profile strip and diagnostics expansion', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: OrbitHomeScreen())),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Profiles'), findsOneWidget);
    expect(find.text('Commute'), findsOneWidget);
    expect(find.text('Focus'), findsOneWidget);
    expect(find.text('Social'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);

    expect(find.text('Show diagnostics'), findsOneWidget);
    await tester.tap(find.text('Show diagnostics'));
    await tester.pumpAndSettle();

    expect(find.text('Start Music'), findsOneWidget);
    expect(find.text('Burst Test'), findsOneWidget);
  });
}
