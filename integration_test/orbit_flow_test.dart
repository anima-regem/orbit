import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbit/orbit/orbit_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dashboard and settings navigation smoke test', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: OrbitLiteApp()));
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Dashboard'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);

    await tester.tap(find.text('Settings').last);
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Overlay Behavior'), findsOneWidget);
  }, skip: true);
}
