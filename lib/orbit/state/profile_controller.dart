import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/orbit_settings.dart';
import 'orbit_analytics_facade.dart';
import 'orbit_settings_controller.dart';

final profileControllerProvider = Provider<ProfileController>((Ref ref) {
  return ProfileController(ref);
});

class ProfileController {
  ProfileController(this._ref);

  final Ref _ref;

  static const Set<String> _commutePackages = <String>{
    'com.instagram.android',
    'com.whatsapp',
    'com.google.android.gm',
  };

  static const Set<String> _focusPackages = <String>{
    'com.google.android.gm',
    'com.slack.android',
  };

  static const Set<String> _socialPackages = <String>{
    'com.instagram.android',
    'com.whatsapp',
    'org.telegram.messenger',
    'com.facebook.orca',
    'com.snapchat.android',
    'com.slack.android',
  };

  Future<void> applyPreset(
    OrbitProfileId profile, {
    String source = 'quick_strip',
  }) async {
    final OrbitSettingsController controller = _ref.read(
      orbitSettingsControllerProvider.notifier,
    );
    final OrbitSettings current =
        _ref.read(orbitSettingsControllerProvider).valueOrNull ??
        OrbitSettings.defaults();

    OrbitSettings next = current.copyWith(activeProfileId: profile);

    switch (profile) {
      case OrbitProfileId.commute:
        next = next.copyWith(
          overlayEnabled: true,
          musicEnabled: true,
          musicPersistent: true,
          displaySeconds: 4.2,
          reducedMotionEnabled: false,
          selectedNotificationPackages: _commutePackages,
          lanePreset: OrbitLanePreset.balanced,
        );
        break;
      case OrbitProfileId.focus:
        next = next.copyWith(
          overlayEnabled: true,
          musicEnabled: true,
          musicPersistent: false,
          displaySeconds: 3.2,
          reducedMotionEnabled: true,
          selectedNotificationPackages: _focusPackages,
          lanePreset: OrbitLanePreset.relaxed,
        );
        break;
      case OrbitProfileId.social:
        next = next.copyWith(
          overlayEnabled: true,
          musicEnabled: true,
          musicPersistent: true,
          displaySeconds: 4.4,
          reducedMotionEnabled: false,
          selectedNotificationPackages: _socialPackages,
          lanePreset: OrbitLanePreset.tight,
        );
        break;
      case OrbitProfileId.custom:
        break;
    }

    await controller.updateWith((OrbitSettings _) => next);

    await _ref
        .read(orbitAnalyticsFacadeProvider)
        .track(
          'profile_changed',
          properties: <String, Object?>{
            'profile_id': profile.value,
            'source': source,
          },
        );
  }
}
