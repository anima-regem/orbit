enum OrbitProfileId {
  commute('commute'),
  focus('focus'),
  social('social'),
  custom('custom');

  const OrbitProfileId(this.value);

  final String value;

  static OrbitProfileId fromValue(String? raw) {
    return OrbitProfileId.values.firstWhere(
      (OrbitProfileId entry) => entry.value == raw,
      orElse: () => OrbitProfileId.commute,
    );
  }
}

enum OrbitLanePreset {
  tight('tight'),
  balanced('balanced'),
  relaxed('relaxed');

  const OrbitLanePreset(this.value);

  final String value;

  static OrbitLanePreset fromValue(String? raw) {
    return OrbitLanePreset.values.firstWhere(
      (OrbitLanePreset entry) => entry.value == raw,
      orElse: () => OrbitLanePreset.balanced,
    );
  }
}

class OrbitSettings {
  const OrbitSettings({
    required this.overlayEnabled,
    required this.musicEnabled,
    required this.musicPersistent,
    required this.displaySeconds,
    required this.overlayOffsetXPx,
    required this.overlayOffsetYPx,
    required this.overlayZAxisPx,
    required this.overlayWidthFactor,
    required this.overlayCompactHeightDp,
    required this.dynamicThemeEnabled,
    required this.reducedMotionEnabled,
    required this.selectedNotificationPackages,
    required this.activeProfileId,
    required this.lanePreset,
    required this.analyticsEnabled,
  });

  factory OrbitSettings.defaults() {
    return const OrbitSettings(
      overlayEnabled: true,
      musicEnabled: true,
      musicPersistent: true,
      displaySeconds: 4.0,
      overlayOffsetXPx: 0,
      overlayOffsetYPx: 0,
      overlayZAxisPx: 0,
      overlayWidthFactor: 0.42,
      overlayCompactHeightDp: 52,
      dynamicThemeEnabled: true,
      reducedMotionEnabled: false,
      selectedNotificationPackages: <String>{
        'com.instagram.android',
        'com.whatsapp',
      },
      activeProfileId: OrbitProfileId.commute,
      lanePreset: OrbitLanePreset.balanced,
      analyticsEnabled: true,
    );
  }

  final bool overlayEnabled;
  final bool musicEnabled;
  final bool musicPersistent;
  final double displaySeconds;
  final double overlayOffsetXPx;
  final double overlayOffsetYPx;
  final double overlayZAxisPx;
  final double overlayWidthFactor;
  final double overlayCompactHeightDp;
  final bool dynamicThemeEnabled;
  final bool reducedMotionEnabled;
  final Set<String> selectedNotificationPackages;
  final OrbitProfileId activeProfileId;
  final OrbitLanePreset lanePreset;
  final bool analyticsEnabled;

  OrbitSettings copyWith({
    bool? overlayEnabled,
    bool? musicEnabled,
    bool? musicPersistent,
    double? displaySeconds,
    double? overlayOffsetXPx,
    double? overlayOffsetYPx,
    double? overlayZAxisPx,
    double? overlayWidthFactor,
    double? overlayCompactHeightDp,
    bool? dynamicThemeEnabled,
    bool? reducedMotionEnabled,
    Set<String>? selectedNotificationPackages,
    OrbitProfileId? activeProfileId,
    OrbitLanePreset? lanePreset,
    bool? analyticsEnabled,
  }) {
    return OrbitSettings(
      overlayEnabled: overlayEnabled ?? this.overlayEnabled,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      musicPersistent: musicPersistent ?? this.musicPersistent,
      displaySeconds: displaySeconds ?? this.displaySeconds,
      overlayOffsetXPx: overlayOffsetXPx ?? this.overlayOffsetXPx,
      overlayOffsetYPx: overlayOffsetYPx ?? this.overlayOffsetYPx,
      overlayZAxisPx: overlayZAxisPx ?? this.overlayZAxisPx,
      overlayWidthFactor: overlayWidthFactor ?? this.overlayWidthFactor,
      overlayCompactHeightDp:
          overlayCompactHeightDp ?? this.overlayCompactHeightDp,
      dynamicThemeEnabled: dynamicThemeEnabled ?? this.dynamicThemeEnabled,
      reducedMotionEnabled: reducedMotionEnabled ?? this.reducedMotionEnabled,
      selectedNotificationPackages:
          selectedNotificationPackages ?? this.selectedNotificationPackages,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      lanePreset: lanePreset ?? this.lanePreset,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
    );
  }
}
