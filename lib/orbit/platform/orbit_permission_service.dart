import 'package:flutter/services.dart';

import '../domain/orbit_settings.dart';
import '../models/orbit_installed_app.dart';

enum OrbitDebugOverlayAction {
  musicStart('music_start'),
  trackChange('track_change'),
  notification('notification'),
  burst('burst'),
  musicPause('music_pause'),
  musicAndNotification('music_and_notification');

  const OrbitDebugOverlayAction(this.wireValue);

  final String wireValue;
}

class OrbitPermissionStatus {
  const OrbitPermissionStatus({
    required this.postNotificationsGranted,
    required this.notificationAccessGranted,
    required this.overlayGranted,
    this.bridgeAvailable = true,
  });

  const OrbitPermissionStatus.granted()
    : postNotificationsGranted = true,
      notificationAccessGranted = true,
      overlayGranted = true,
      bridgeAvailable = true;

  final bool postNotificationsGranted;
  final bool notificationAccessGranted;
  final bool overlayGranted;
  final bool bridgeAvailable;

  bool get allGranted =>
      postNotificationsGranted && notificationAccessGranted && overlayGranted;

  int get grantedCount {
    int count = 0;
    if (postNotificationsGranted) {
      count++;
    }
    if (notificationAccessGranted) {
      count++;
    }
    if (overlayGranted) {
      count++;
    }
    return count;
  }

  factory OrbitPermissionStatus.fromChannelMap(Map<dynamic, dynamic> raw) {
    bool readBool(dynamic value) => value == true;

    return OrbitPermissionStatus(
      postNotificationsGranted: readBool(raw['postNotificationsGranted']),
      notificationAccessGranted: readBool(raw['notificationAccessGranted']),
      overlayGranted: readBool(raw['overlayGranted']),
      bridgeAvailable: true,
    );
  }

  Map<String, Object?> toSnapshot() {
    return <String, Object?>{
      'post_notifications': postNotificationsGranted,
      'notification_access': notificationAccessGranted,
      'overlay_permission': overlayGranted,
    };
  }
}

class OrbitPermissionService {
  const OrbitPermissionService();

  static const MethodChannel _channel = MethodChannel('orbit/permissions');

  Future<OrbitPermissionStatus> getPermissionStatus() async {
    try {
      final Map<dynamic, dynamic>? raw = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getPermissionStatus');
      if (raw == null) {
        return const OrbitPermissionStatus(
          postNotificationsGranted: false,
          notificationAccessGranted: false,
          overlayGranted: false,
        );
      }

      return OrbitPermissionStatus.fromChannelMap(raw);
    } on MissingPluginException {
      return const OrbitPermissionStatus(
        postNotificationsGranted: true,
        notificationAccessGranted: true,
        overlayGranted: true,
        bridgeAvailable: false,
      );
    }
  }

  Future<bool> requestPostNotifications() async {
    try {
      final bool? granted = await _channel.invokeMethod<bool>(
        'requestPostNotifications',
      );
      return granted ?? false;
    } on MissingPluginException {
      return true;
    }
  }

  Future<bool> openNotificationAccessSettings() async {
    return _openSettingsMethod('openNotificationAccessSettings');
  }

  Future<bool> openOverlaySettings() async {
    return _openSettingsMethod('openOverlaySettings');
  }

  Future<bool> openAppNotificationSettings() async {
    return _openSettingsMethod('openAppNotificationSettings');
  }

  Future<bool> openAppNotificationSettingsForPackage(String packageName) async {
    try {
      final bool? opened = await _channel.invokeMethod<bool>(
        'openAppNotificationSettings',
        <String, dynamic>{'packageName': packageName},
      );
      return opened ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<List<OrbitInstalledApp>> getInstalledApps() async {
    try {
      final List<dynamic>? rawList = await _channel.invokeMethod<List<dynamic>>(
        'getInstalledApps',
      );
      if (rawList == null) {
        return const <OrbitInstalledApp>[];
      }

      return rawList
          .whereType<Map<dynamic, dynamic>>()
          .map(OrbitInstalledApp.fromMap)
          .where((OrbitInstalledApp app) => app.packageName.isNotEmpty)
          .toList();
    } on MissingPluginException {
      return const <OrbitInstalledApp>[];
    }
  }

  Future<bool> setOverlayConfigV2(OrbitSettings settings) async {
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'setOverlayConfigV2',
        <String, dynamic>{
          'schemaVersion': 2,
          'layout': const <String, dynamic>{
            'horizontalOffsetPx': 0,
            'verticalOffsetPx': 0,
            'compactWidthFactor': 0.42,
            'compactHeightDp': 52,
            'expandedWidthFactor': 0.74,
            'musicExpandedHeightDp': 196,
            'notificationExpandedHeightDp': 140,
          },
          'behavior': <String, dynamic>{
            'musicPersistent': settings.musicPersistent,
            'reducedMotion': settings.reducedMotionEnabled,
          },
          'theme': <String, dynamic>{
            'dynamicThemeEnabled': settings.dynamicThemeEnabled,
            'styleId': 'premium_minimal',
          },
          'filters': <String, dynamic>{
            'allowedPackages': settings.selectedNotificationPackages.toList(),
          },
        },
      );
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> triggerDebugOverlayEventV2({
    required OrbitDebugOverlayAction action,
    String? sourcePackage,
    String? sourceName,
    String? title,
    String? body,
  }) async {
    try {
      final Map<String, dynamic> payload = <String, dynamic>{
        'schemaVersion': 2,
        'action': action.wireValue,
      };
      if (sourcePackage != null) {
        payload['sourcePackage'] = sourcePackage;
      }
      if (sourceName != null) {
        payload['sourceName'] = sourceName;
      }
      if (title != null) {
        payload['title'] = title;
      }
      if (body != null) {
        payload['body'] = body;
      }

      final bool? ok = await _channel.invokeMethod<bool>(
        'triggerDebugOverlayEventV2',
        payload,
      );
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> sendMediaAction(String action) async {
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'sendMediaAction',
        <String, dynamic>{'action': action},
      );
      return ok ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> _openSettingsMethod(String method) async {
    try {
      final bool? opened = await _channel.invokeMethod<bool>(method);
      return opened ?? false;
    } on MissingPluginException {
      return false;
    }
  }
}
