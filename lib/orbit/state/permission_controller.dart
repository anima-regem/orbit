import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/orbit_permission_service.dart';

final orbitPermissionServiceProvider = Provider<OrbitPermissionService>((
  Ref ref,
) {
  return const OrbitPermissionService();
});

final permissionControllerProvider =
    AsyncNotifierProvider<PermissionController, OrbitPermissionStatus>(
      PermissionController.new,
    );

class PermissionController extends AsyncNotifier<OrbitPermissionStatus> {
  @override
  Future<OrbitPermissionStatus> build() async {
    return _load();
  }

  Future<OrbitPermissionStatus> _load() {
    return ref.read(orbitPermissionServiceProvider).getPermissionStatus();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _load());
  }

  Future<bool> requestPostNotifications() async {
    try {
      final bool granted = await ref
          .read(orbitPermissionServiceProvider)
          .requestPostNotifications();
      state = AsyncData(await _load());
      return granted;
    } on PlatformException {
      return false;
    }
  }

  Future<void> openNotificationAccessSettings() async {
    await ref
        .read(orbitPermissionServiceProvider)
        .openNotificationAccessSettings();
  }

  Future<void> openOverlaySettings() async {
    await ref.read(orbitPermissionServiceProvider).openOverlaySettings();
  }

  Future<void> openAppNotificationSettings() async {
    await ref
        .read(orbitPermissionServiceProvider)
        .openAppNotificationSettings();
  }
}
