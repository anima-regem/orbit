import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/noop_orbit_analytics.dart';
import '../analytics/orbit_analytics.dart';
import '../analytics/segment_orbit_analytics.dart';
import '../domain/orbit_settings.dart';
import '../platform/orbit_permission_service.dart';
import 'orbit_settings_controller.dart';
import 'permission_controller.dart';

const String _segmentWriteKey = String.fromEnvironment('SEGMENT_WRITE_KEY');

final orbitAnalyticsProvider = Provider<OrbitAnalytics>((Ref ref) {
  if (_segmentWriteKey.trim().isEmpty) {
    return const NoopOrbitAnalytics();
  }
  return SegmentOrbitAnalytics(writeKey: _segmentWriteKey.trim());
});

final orbitSessionIdProvider = Provider<String>((Ref ref) {
  final int nonce = Random().nextInt(1 << 32);
  return '${DateTime.now().millisecondsSinceEpoch}-$nonce';
});

final orbitAnalyticsFacadeProvider = Provider<OrbitAnalyticsFacade>((Ref ref) {
  return OrbitAnalyticsFacade(ref);
});

class OrbitAnalyticsFacade {
  OrbitAnalyticsFacade(this._ref);

  final Ref _ref;

  Future<void> track(
    String event, {
    Map<String, Object?> properties = const <String, Object?>{},
  }) async {
    final OrbitSettings? settings = _ref
        .read(orbitSettingsControllerProvider)
        .valueOrNull;
    if (settings == null || !settings.analyticsEnabled) {
      return;
    }

    final OrbitPermissionStatus permission =
        _ref.read(permissionControllerProvider).valueOrNull ??
        const OrbitPermissionStatus(
          postNotificationsGranted: false,
          notificationAccessGranted: false,
          overlayGranted: false,
          bridgeAvailable: true,
        );

    final Map<String, Object?> merged = <String, Object?>{
      'persona_context': _derivePersonaContext(settings),
      'session_id': _ref.read(orbitSessionIdProvider),
      'app_in_foreground': true,
      'permission_state_snapshot': permission.toSnapshot(),
      ...properties,
    };

    await _ref
        .read(orbitAnalyticsProvider)
        .track(
          event: event,
          sessionId: _ref.read(orbitSessionIdProvider),
          properties: merged,
        );
  }

  String _derivePersonaContext(OrbitSettings settings) {
    switch (settings.activeProfileId) {
      case OrbitProfileId.commute:
        return 'commuter_listener';
      case OrbitProfileId.focus:
        return 'deep_work_professional';
      case OrbitProfileId.social:
        return 'social_responder';
      case OrbitProfileId.custom:
        break;
    }

    if (settings.reducedMotionEnabled) {
      return 'accessibility_first_user';
    }
    if (!settings.musicEnabled &&
        settings.selectedNotificationPackages.length <= 2) {
      return 'deep_work_professional';
    }
    if (settings.selectedNotificationPackages.length >= 6) {
      return 'social_responder';
    }
    if (settings.overlayWidthFactor != 0.42 ||
        settings.overlayCompactHeightDp != 52 ||
        settings.overlayOffsetXPx != 0 ||
        settings.overlayOffsetYPx != 0 ||
        settings.overlayZAxisPx != 0) {
      return 'control_seeker';
    }
    return 'commuter_listener';
  }
}
