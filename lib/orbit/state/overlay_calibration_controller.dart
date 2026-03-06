import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/orbit_settings.dart';
import 'orbit_analytics_facade.dart';
import 'orbit_settings_controller.dart';

final overlayCalibrationControllerProvider =
    Provider<OverlayCalibrationController>((Ref ref) {
      return OverlayCalibrationController(ref);
    });

class OverlayCalibrationController {
  OverlayCalibrationController(this._ref);

  final Ref _ref;

  static const Map<OrbitLanePreset, double> _presetOffsets =
      <OrbitLanePreset, double>{
        OrbitLanePreset.tight: -8,
        OrbitLanePreset.balanced: 0,
        OrbitLanePreset.relaxed: 14,
      };

  Future<void> trackOpened({required String source}) async {
    await _ref
        .read(orbitAnalyticsFacadeProvider)
        .track(
          'lane_calibration_opened',
          properties: <String, Object?>{'source': source},
        );
  }

  Future<void> applyLanePreset(OrbitLanePreset preset) async {
    final OrbitSettingsController settingsController = _ref.read(
      orbitSettingsControllerProvider.notifier,
    );

    await settingsController.updateWith((OrbitSettings current) {
      return current.copyWith(
        lanePreset: preset,
        overlayOffsetYPx: _presetOffsets[preset] ?? 0,
        activeProfileId: OrbitProfileId.custom,
      );
    });

    await _ref
        .read(orbitAnalyticsFacadeProvider)
        .track(
          'lane_calibration_saved',
          properties: <String, Object?>{
            'lane_preset': preset.value,
            'offset_y_px': _presetOffsets[preset] ?? 0,
          },
        );
  }

  Future<void> setLaneOffset(double offsetY) async {
    await _ref
        .read(orbitSettingsControllerProvider.notifier)
        .setOffsetY(offsetY);
  }

  Future<void> saveCustomLaneOffset(double offsetY) async {
    await _ref
        .read(orbitSettingsControllerProvider.notifier)
        .setOffsetY(offsetY);
    final OrbitSettings current =
        _ref.read(orbitSettingsControllerProvider).valueOrNull ??
        OrbitSettings.defaults();

    await _ref
        .read(orbitAnalyticsFacadeProvider)
        .track(
          'lane_calibration_saved',
          properties: <String, Object?>{
            'lane_preset': current.lanePreset.value,
            'offset_y_px': offsetY,
          },
        );
  }
}
