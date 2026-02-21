import 'package:shared_preferences/shared_preferences.dart';

import '../domain/orbit_settings.dart';

class OrbitSettingsRepository {
  const OrbitSettingsRepository();

  static const String _overlayEnabledKey = 'overlay_enabled';
  static const String _musicEnabledKey = 'music_enabled';
  static const String _musicPersistentKey = 'music_persistent';
  static const String _displaySecondsKey = 'display_seconds';
  static const String _overlayOffsetXPxKey = 'overlay_offset_x_px';
  static const String _overlayOffsetYPxKey = 'overlay_offset_y_px';
  static const String _overlayZAxisPxKey = 'overlay_z_axis_px';
  static const String _overlayWidthFactorKey = 'overlay_width_factor';
  static const String _overlayCompactHeightDpKey = 'overlay_compact_height_dp';
  static const String _dynamicThemeEnabledKey = 'dynamic_theme_enabled';
  static const String _reducedMotionEnabledKey = 'reduced_motion_enabled';
  static const String _selectedNotificationPackagesKey =
      'selected_notification_packages';
  static const String _analyticsEnabledKey = 'analytics_enabled';

  Future<OrbitSettings> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final OrbitSettings defaults = OrbitSettings.defaults();

    return OrbitSettings(
      overlayEnabled:
          prefs.getBool(_overlayEnabledKey) ?? defaults.overlayEnabled,
      musicEnabled: prefs.getBool(_musicEnabledKey) ?? defaults.musicEnabled,
      musicPersistent:
          prefs.getBool(_musicPersistentKey) ?? defaults.musicPersistent,
      displaySeconds:
          prefs.getDouble(_displaySecondsKey) ?? defaults.displaySeconds,
      overlayOffsetXPx:
          prefs.getDouble(_overlayOffsetXPxKey) ?? defaults.overlayOffsetXPx,
      overlayOffsetYPx:
          prefs.getDouble(_overlayOffsetYPxKey) ?? defaults.overlayOffsetYPx,
      overlayZAxisPx:
          prefs.getDouble(_overlayZAxisPxKey) ?? defaults.overlayZAxisPx,
      overlayWidthFactor:
          prefs.getDouble(_overlayWidthFactorKey) ??
          defaults.overlayWidthFactor,
      overlayCompactHeightDp:
          prefs.getDouble(_overlayCompactHeightDpKey) ??
          defaults.overlayCompactHeightDp,
      dynamicThemeEnabled:
          prefs.getBool(_dynamicThemeEnabledKey) ??
          defaults.dynamicThemeEnabled,
      reducedMotionEnabled:
          prefs.getBool(_reducedMotionEnabledKey) ??
          defaults.reducedMotionEnabled,
      selectedNotificationPackages:
          (prefs.getStringList(_selectedNotificationPackagesKey) ??
                  defaults.selectedNotificationPackages.toList())
              .map((String value) => value.toLowerCase().trim())
              .where((String value) => value.isNotEmpty)
              .toSet(),
      analyticsEnabled:
          prefs.getBool(_analyticsEnabledKey) ?? defaults.analyticsEnabled,
    );
  }

  Future<void> save(OrbitSettings settings) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_overlayEnabledKey, settings.overlayEnabled);
    await prefs.setBool(_musicEnabledKey, settings.musicEnabled);
    await prefs.setBool(_musicPersistentKey, settings.musicPersistent);
    await prefs.setDouble(_displaySecondsKey, settings.displaySeconds);
    await prefs.setDouble(_overlayOffsetXPxKey, settings.overlayOffsetXPx);
    await prefs.setDouble(_overlayOffsetYPxKey, settings.overlayOffsetYPx);
    await prefs.setDouble(_overlayZAxisPxKey, settings.overlayZAxisPx);
    await prefs.setDouble(_overlayWidthFactorKey, settings.overlayWidthFactor);
    await prefs.setDouble(
      _overlayCompactHeightDpKey,
      settings.overlayCompactHeightDp,
    );
    await prefs.setBool(_dynamicThemeEnabledKey, settings.dynamicThemeEnabled);
    await prefs.setBool(
      _reducedMotionEnabledKey,
      settings.reducedMotionEnabled,
    );
    await prefs.setStringList(
      _selectedNotificationPackagesKey,
      settings.selectedNotificationPackages.toList(),
    );
    await prefs.setBool(_analyticsEnabledKey, settings.analyticsEnabled);
  }
}
