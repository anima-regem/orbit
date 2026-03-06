import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/orbit_settings.dart';
import 'orbit_settings_repository.dart';

final orbitSettingsRepositoryProvider = Provider<OrbitSettingsRepository>((
  Ref ref,
) {
  return const OrbitSettingsRepository();
});

final orbitSettingsControllerProvider =
    AsyncNotifierProvider<OrbitSettingsController, OrbitSettings>(
      OrbitSettingsController.new,
    );

class OrbitSettingsController extends AsyncNotifier<OrbitSettings> {
  @override
  Future<OrbitSettings> build() async {
    final OrbitSettingsRepository repository = ref.read(
      orbitSettingsRepositoryProvider,
    );
    return repository.load();
  }

  OrbitSettings get _current => state.valueOrNull ?? OrbitSettings.defaults();

  OrbitSettings _withCustomProfile(OrbitSettings settings) {
    if (settings.activeProfileId == OrbitProfileId.custom) {
      return settings;
    }
    return settings.copyWith(activeProfileId: OrbitProfileId.custom);
  }

  Future<void> updateWith(
    OrbitSettings Function(OrbitSettings value) transform,
  ) async {
    final OrbitSettings next = transform(_current);
    state = AsyncData(next);
    await ref.read(orbitSettingsRepositoryProvider).save(next);
  }

  Future<void> setOverlayEnabled(bool value) async {
    await updateWith((OrbitSettings current) {
      return _withCustomProfile(current.copyWith(overlayEnabled: value));
    });
  }

  Future<void> setMusicEnabled(bool value) async {
    await updateWith((OrbitSettings current) {
      return _withCustomProfile(current.copyWith(musicEnabled: value));
    });
  }

  Future<void> setMusicPersistent(bool value) async {
    await updateWith((OrbitSettings current) {
      return _withCustomProfile(current.copyWith(musicPersistent: value));
    });
  }

  Future<void> setDisplaySeconds(double value) async {
    await updateWith((OrbitSettings current) {
      return _withCustomProfile(current.copyWith(displaySeconds: value));
    });
  }

  Future<void> setDynamicThemeEnabled(bool value) async {
    await updateWith((OrbitSettings current) {
      return _withCustomProfile(current.copyWith(dynamicThemeEnabled: value));
    });
  }

  Future<void> setReducedMotionEnabled(bool value) async {
    await updateWith((OrbitSettings current) {
      return _withCustomProfile(current.copyWith(reducedMotionEnabled: value));
    });
  }

  Future<void> setAnalyticsEnabled(bool value) async {
    await updateWith((OrbitSettings current) {
      return current.copyWith(analyticsEnabled: value);
    });
  }

  Future<void> setOffsetY(double value) async {
    await updateWith((OrbitSettings current) {
      return _withCustomProfile(current.copyWith(overlayOffsetYPx: value));
    });
  }

  Future<void> setOffsetX(double value) async {
    await updateWith((OrbitSettings current) {
      return _withCustomProfile(current.copyWith(overlayOffsetXPx: value));
    });
  }

  Future<void> setZAxis(double value) async {
    await updateWith((OrbitSettings current) {
      return _withCustomProfile(current.copyWith(overlayZAxisPx: value));
    });
  }

  Future<void> setWidthFactor(double value) async {
    await updateWith((OrbitSettings current) {
      return _withCustomProfile(current.copyWith(overlayWidthFactor: value));
    });
  }

  Future<void> setCompactHeight(double value) async {
    await updateWith((OrbitSettings current) {
      return _withCustomProfile(
        current.copyWith(overlayCompactHeightDp: value),
      );
    });
  }

  Future<void> setSelectedNotificationPackages(Set<String> packages) async {
    await updateWith((OrbitSettings current) {
      return _withCustomProfile(
        current.copyWith(selectedNotificationPackages: packages),
      );
    });
  }

  Future<void> setLanePreset(OrbitLanePreset preset) async {
    await updateWith((OrbitSettings current) {
      return _withCustomProfile(current.copyWith(lanePreset: preset));
    });
  }

  Future<void> setActiveProfileId(OrbitProfileId profileId) async {
    await updateWith((OrbitSettings current) {
      return current.copyWith(activeProfileId: profileId);
    });
  }

  Future<void> resetPlacement() async {
    await updateWith((OrbitSettings current) {
      return current.copyWith(
        overlayOffsetXPx: 0,
        overlayOffsetYPx: 0,
        overlayZAxisPx: 0,
        lanePreset: OrbitLanePreset.balanced,
        overlayWidthFactor: 0.42,
        overlayCompactHeightDp: 52,
        activeProfileId: OrbitProfileId.custom,
      );
    });
  }
}
