class OrbitSettings {
  const OrbitSettings({
    required this.overlayEnabled,
    required this.musicEnabled,
    required this.musicPersistent,
    required this.displaySeconds,
    required this.overlayOffsetXPx,
    required this.overlayOffsetYPx,
    required this.overlayWidthFactor,
    required this.overlayCompactHeightDp,
    required this.dynamicThemeEnabled,
    required this.reducedMotionEnabled,
    required this.selectedNotificationPackages,
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
      overlayWidthFactor: 0.42,
      overlayCompactHeightDp: 52,
      dynamicThemeEnabled: true,
      reducedMotionEnabled: false,
      selectedNotificationPackages: <String>{
        'com.instagram.android',
        'com.whatsapp',
      },
      analyticsEnabled: true,
    );
  }

  final bool overlayEnabled;
  final bool musicEnabled;
  final bool musicPersistent;
  final double displaySeconds;
  final double overlayOffsetXPx;
  final double overlayOffsetYPx;
  final double overlayWidthFactor;
  final double overlayCompactHeightDp;
  final bool dynamicThemeEnabled;
  final bool reducedMotionEnabled;
  final Set<String> selectedNotificationPackages;
  final bool analyticsEnabled;

  OrbitSettings copyWith({
    bool? overlayEnabled,
    bool? musicEnabled,
    bool? musicPersistent,
    double? displaySeconds,
    double? overlayOffsetXPx,
    double? overlayOffsetYPx,
    double? overlayWidthFactor,
    double? overlayCompactHeightDp,
    bool? dynamicThemeEnabled,
    bool? reducedMotionEnabled,
    Set<String>? selectedNotificationPackages,
    bool? analyticsEnabled,
  }) {
    return OrbitSettings(
      overlayEnabled: overlayEnabled ?? this.overlayEnabled,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      musicPersistent: musicPersistent ?? this.musicPersistent,
      displaySeconds: displaySeconds ?? this.displaySeconds,
      overlayOffsetXPx: overlayOffsetXPx ?? this.overlayOffsetXPx,
      overlayOffsetYPx: overlayOffsetYPx ?? this.overlayOffsetYPx,
      overlayWidthFactor: overlayWidthFactor ?? this.overlayWidthFactor,
      overlayCompactHeightDp:
          overlayCompactHeightDp ?? this.overlayCompactHeightDp,
      dynamicThemeEnabled: dynamicThemeEnabled ?? this.dynamicThemeEnabled,
      reducedMotionEnabled: reducedMotionEnabled ?? this.reducedMotionEnabled,
      selectedNotificationPackages:
          selectedNotificationPackages ?? this.selectedNotificationPackages,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
    );
  }
}
