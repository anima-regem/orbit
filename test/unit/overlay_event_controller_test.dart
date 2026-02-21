import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/orbit/domain/orbit_event_v2.dart';
import 'package:orbit/orbit/platform/orbit_event_channel.dart';
import 'package:orbit/orbit/platform/orbit_permission_service.dart';
import 'package:orbit/orbit/state/overlay_event_controller.dart';
import 'package:orbit/orbit/state/permission_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'updates status on music, notification, and musicPaused events',
    () async {
      final _FakeOrbitEventChannel channel = _FakeOrbitEventChannel();
      final _FakePermissionService permission = _FakePermissionService();

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          orbitEventChannelProvider.overrideWithValue(channel),
          orbitPermissionServiceProvider.overrideWithValue(permission),
        ],
      );

      addTearDown(() async {
        container.dispose();
        await channel.dispose();
      });

      container.read(overlayEventControllerProvider);

      channel.emit(
        _event(
          id: 'music-1',
          kind: OrbitEventKind.music,
          packageName: 'com.spotify.music',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final OverlayEventState afterMusic = container.read(
        overlayEventControllerProvider,
      );
      expect(afterMusic.activeEvent?.eventId, 'music-1');
      expect(afterMusic.musicPlaying, isTrue);

      channel.emit(
        _event(
          id: 'notif-1',
          kind: OrbitEventKind.notification,
          packageName: 'com.instagram.android',
          priority: OrbitEventPriority.high,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final OverlayEventState afterNotification = container.read(
        overlayEventControllerProvider,
      );
      expect(afterNotification.activeEvent?.eventId, 'notif-1');
      expect(afterNotification.lastEvent?.eventId, 'notif-1');
      expect(afterNotification.musicPlaying, isTrue);

      channel.emit(
        _event(
          id: 'pause-1',
          kind: OrbitEventKind.musicPaused,
          packageName: 'system',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final OverlayEventState afterPause = container.read(
        overlayEventControllerProvider,
      );
      expect(afterPause.activeEvent, isNull);
      expect(afterPause.lastEvent?.kind, OrbitEventKind.musicPaused);
      expect(afterPause.musicPlaying, isFalse);
    },
  );

  test('quick actions call native debug trigger API', () async {
    final _FakeOrbitEventChannel channel = _FakeOrbitEventChannel();
    final _FakePermissionService permission = _FakePermissionService();

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        orbitEventChannelProvider.overrideWithValue(channel),
        orbitPermissionServiceProvider.overrideWithValue(permission),
      ],
    );

    addTearDown(() async {
      container.dispose();
      await channel.dispose();
    });

    final OverlayEventController controller = container.read(
      overlayEventControllerProvider.notifier,
    );

    await controller.triggerMusicStart();
    await controller.triggerTrackChange();
    await controller.triggerNotification(
      packageName: 'com.whatsapp',
      sourceName: 'WhatsApp',
      title: 'Ping',
      body: 'Hello',
    );

    expect(permission.calls.length, 3);
    expect(permission.calls[0]['action'], 'music_start');
    expect(permission.calls[1]['action'], 'track_change');
    expect(permission.calls[2]['action'], 'notification');
    expect(permission.calls[2]['sourcePackage'], 'com.whatsapp');
    expect(permission.calls[2]['sourceName'], 'WhatsApp');
    expect(permission.calls[2]['title'], 'Ping');
    expect(permission.calls[2]['body'], 'Hello');
  });
}

OrbitEventV2 _event({
  required String id,
  required OrbitEventKind kind,
  required String packageName,
  OrbitEventPriority priority = OrbitEventPriority.normal,
}) {
  return OrbitEventV2(
    eventId: id,
    kind: kind,
    source: OrbitEventSource(packageName: packageName),
    content: OrbitEventContent(title: id),
    timing: OrbitEventTiming(displayMs: 4000, receivedAt: DateTime.now()),
    priority: priority,
  );
}

class _FakeOrbitEventChannel extends OrbitEventChannel {
  final StreamController<OrbitEventV2> _streamController =
      StreamController<OrbitEventV2>.broadcast();

  @override
  Stream<OrbitEventV2> get events => _streamController.stream;

  void emit(OrbitEventV2 event) {
    _streamController.add(event);
  }

  @override
  Future<void> dispose() async {
    await _streamController.close();
    await super.dispose();
  }
}

class _FakePermissionService extends OrbitPermissionService {
  final List<Map<String, String?>> calls = <Map<String, String?>>[];

  @override
  Future<bool> triggerDebugOverlayEventV2({
    required OrbitDebugOverlayAction action,
    String? sourcePackage,
    String? sourceName,
    String? title,
    String? body,
  }) async {
    calls.add(<String, String?>{
      'action': action.wireValue,
      'sourcePackage': sourcePackage,
      'sourceName': sourceName,
      'title': title,
      'body': body,
    });
    return true;
  }
}
