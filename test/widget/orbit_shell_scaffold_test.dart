import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/orbit/features/shell/orbit_shell_scaffold.dart';
import 'package:orbit/orbit/platform/orbit_permission_service.dart';
import 'package:orbit/orbit/state/permission_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('shows setup wizard gate when permissions are missing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          permissionControllerProvider.overrideWith(
            () => _TestPermissionController(
              const OrbitPermissionStatus(
                postNotificationsGranted: false,
                notificationAccessGranted: false,
                overlayGranted: false,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: OrbitShellScaffold()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Setup Orbit'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Step 1 of 4'), findsOneWidget);
  });

  testWidgets('shows home and settings tabs when permissions are granted', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          permissionControllerProvider.overrideWith(
            () => _TestPermissionController(
              const OrbitPermissionStatus.granted(),
            ),
          ),
        ],
        child: const MaterialApp(home: OrbitShellScaffold()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Orbit Home'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}

class _TestPermissionController extends PermissionController {
  _TestPermissionController(this.status);

  final OrbitPermissionStatus status;

  @override
  Future<OrbitPermissionStatus> build() async {
    return status;
  }

  @override
  Future<bool> requestPostNotifications() async {
    return true;
  }

  @override
  Future<void> openNotificationAccessSettings() async {}

  @override
  Future<void> openOverlaySettings() async {}
}
