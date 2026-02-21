import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/orbit/features/onboarding/setup_flow_screen.dart';
import 'package:orbit/orbit/platform/orbit_permission_service.dart';
import 'package:orbit/orbit/state/permission_controller.dart';

void main() {
  testWidgets(
    'shows all onboarding steps and progress when permissions missing',
    (WidgetTester tester) async {
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
          child: const MaterialApp(home: Scaffold(body: SetupFlowScreen())),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Step 1'), findsOneWidget);
      expect(find.textContaining('Step 2'), findsOneWidget);
      expect(find.textContaining('/3 complete'), findsWidgets);
      await tester.scrollUntilVisible(find.textContaining('Step 3'), 240);
      expect(find.textContaining('Step 3'), findsOneWidget);
      expect(find.text('Grant permission'), findsOneWidget);
    },
  );
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
