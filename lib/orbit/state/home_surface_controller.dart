import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/orbit_event_v2.dart';
import '../domain/orbit_settings.dart';
import '../platform/orbit_permission_service.dart';
import 'orbit_settings_controller.dart';
import 'overlay_event_controller.dart';
import 'permission_controller.dart';

class HomeSurfaceState {
  const HomeSurfaceState({
    required this.settings,
    required this.permission,
    required this.overlay,
  });

  final OrbitSettings settings;
  final OrbitPermissionStatus permission;
  final OverlayEventState overlay;

  OrbitEventV2? get latestEvent => overlay.activeEvent ?? overlay.lastEvent;

  String get activeLabel {
    final OrbitEventV2? event = latestEvent;
    if (event == null) {
      return 'Idle';
    }
    switch (event.kind) {
      case OrbitEventKind.music:
        return 'Music · ${event.content.title}';
      case OrbitEventKind.notification:
        return 'Notification · ${event.content.title}';
      case OrbitEventKind.musicPaused:
        return 'Music paused';
    }
  }
}

final homeSurfaceStateProvider = Provider<HomeSurfaceState>((Ref ref) {
  final OrbitSettings settings =
      ref.watch(orbitSettingsControllerProvider).valueOrNull ??
      OrbitSettings.defaults();

  final OrbitPermissionStatus permission =
      ref.watch(permissionControllerProvider).valueOrNull ??
      const OrbitPermissionStatus(
        postNotificationsGranted: false,
        notificationAccessGranted: false,
        overlayGranted: false,
        bridgeAvailable: true,
      );

  final OverlayEventState overlay = ref.watch(overlayEventControllerProvider);

  return HomeSurfaceState(
    settings: settings,
    permission: permission,
    overlay: overlay,
  );
});
