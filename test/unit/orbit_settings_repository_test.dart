import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/orbit/domain/orbit_settings.dart';
import 'package:orbit/orbit/state/orbit_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('loads defaults when storage empty', () async {
    final OrbitSettingsRepository repository = const OrbitSettingsRepository();
    final OrbitSettings settings = await repository.load();

    expect(settings.overlayEnabled, isTrue);
    expect(settings.musicEnabled, isTrue);
    expect(
      settings.selectedNotificationPackages,
      contains('com.instagram.android'),
    );
  });

  test('persists and reloads values', () async {
    final OrbitSettingsRepository repository = const OrbitSettingsRepository();

    const OrbitSettings custom = OrbitSettings(
      overlayEnabled: false,
      musicEnabled: false,
      musicPersistent: false,
      displaySeconds: 3.4,
      overlayOffsetXPx: 12,
      overlayOffsetYPx: -5,
      overlayWidthFactor: 0.6,
      overlayCompactHeightDp: 64,
      dynamicThemeEnabled: false,
      reducedMotionEnabled: true,
      selectedNotificationPackages: <String>{'com.whatsapp'},
      analyticsEnabled: false,
    );

    await repository.save(custom);
    final OrbitSettings loaded = await repository.load();

    expect(loaded.overlayEnabled, isFalse);
    expect(loaded.musicEnabled, isFalse);
    expect(loaded.musicPersistent, isFalse);
    expect(loaded.displaySeconds, closeTo(3.4, 0.001));
    expect(loaded.overlayOffsetXPx, 0);
    expect(loaded.overlayOffsetYPx, 0);
    expect(loaded.overlayWidthFactor, closeTo(0.42, 0.001));
    expect(loaded.overlayCompactHeightDp, 52);
    expect(loaded.dynamicThemeEnabled, isFalse);
    expect(loaded.reducedMotionEnabled, isTrue);
    expect(loaded.selectedNotificationPackages, <String>{'com.whatsapp'});
    expect(loaded.analyticsEnabled, isFalse);
  });
}
