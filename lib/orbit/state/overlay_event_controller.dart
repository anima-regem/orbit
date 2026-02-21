import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/orbit_event_v2.dart';
import '../platform/orbit_event_channel.dart';
import '../platform/orbit_permission_service.dart';
import 'orbit_analytics_facade.dart';
import 'permission_controller.dart';

class OverlayEventState {
  const OverlayEventState({
    this.activeEvent,
    this.lastEvent,
    this.musicPlaying = false,
    this.error,
  });

  final OrbitEventV2? activeEvent;
  final OrbitEventV2? lastEvent;
  final bool musicPlaying;
  final String? error;

  OverlayEventState copyWith({
    OrbitEventV2? activeEvent,
    bool clearActiveEvent = false,
    OrbitEventV2? lastEvent,
    bool? musicPlaying,
    String? error,
    bool clearError = false,
  }) {
    return OverlayEventState(
      activeEvent: clearActiveEvent ? null : (activeEvent ?? this.activeEvent),
      lastEvent: lastEvent ?? this.lastEvent,
      musicPlaying: musicPlaying ?? this.musicPlaying,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final orbitEventChannelProvider = Provider<OrbitEventChannel>((Ref ref) {
  final OrbitEventChannel channel = OrbitEventChannel();
  ref.onDispose(() {
    unawaited(channel.dispose());
  });
  return channel;
});

final overlayEventControllerProvider =
    NotifierProvider<OverlayEventController, OverlayEventState>(
      OverlayEventController.new,
    );

class OverlayEventController extends Notifier<OverlayEventState> {
  StreamSubscription<OrbitEventV2>? _eventSubscription;

  @override
  OverlayEventState build() {
    _eventSubscription = ref
        .read(orbitEventChannelProvider)
        .events
        .listen(_handleIncomingEvent);

    ref.onDispose(() {
      _eventSubscription?.cancel();
    });

    return const OverlayEventState();
  }

  Future<void> triggerMusicStart() {
    return _triggerDebugAction(OrbitDebugOverlayAction.musicStart);
  }

  Future<void> triggerTrackChange() {
    return _triggerDebugAction(OrbitDebugOverlayAction.trackChange);
  }

  Future<void> triggerMusicPause() {
    return _triggerDebugAction(OrbitDebugOverlayAction.musicPause);
  }

  Future<void> triggerNotification({
    String packageName = 'com.instagram.android',
    String sourceName = 'Instagram',
    String title = 'Instagram DM',
    String body = 'New message from Alex',
  }) {
    return _triggerDebugAction(
      OrbitDebugOverlayAction.notification,
      sourcePackage: packageName,
      sourceName: sourceName,
      title: title,
      body: body,
    );
  }

  Future<void> triggerBurst() async {
    await ref
        .read(orbitAnalyticsFacadeProvider)
        .track(
          'burst_test_triggered',
          properties: const <String, Object?>{'count': 5},
        );
    await _triggerDebugAction(OrbitDebugOverlayAction.burst);
  }

  Future<void> triggerMusicAndNotification() {
    return _triggerDebugAction(OrbitDebugOverlayAction.musicAndNotification);
  }

  Future<void> _triggerDebugAction(
    OrbitDebugOverlayAction action, {
    String? sourcePackage,
    String? sourceName,
    String? title,
    String? body,
  }) async {
    final bool ok = await ref
        .read(orbitPermissionServiceProvider)
        .triggerDebugOverlayEventV2(
          action: action,
          sourcePackage: sourcePackage,
          sourceName: sourceName,
          title: title,
          body: body,
        );

    if (ok) {
      state = state.copyWith(clearError: true);
      return;
    }

    const String message = 'Native debug trigger failed';
    state = state.copyWith(error: message);
    await ref
        .read(orbitAnalyticsFacadeProvider)
        .track(
          'overlay_error',
          properties: <String, Object?>{
            'stage': 'triggerDebugOverlayEventV2',
            'action': action.wireValue,
            'message': message,
          },
        );
  }

  void _handleIncomingEvent(OrbitEventV2 event) {
    _trackReceivedEvent(event);

    if (event.kind == OrbitEventKind.musicPaused) {
      state = state.copyWith(
        clearActiveEvent: true,
        lastEvent: event,
        musicPlaying: false,
        clearError: true,
      );
      unawaited(
        ref
            .read(orbitAnalyticsFacadeProvider)
            .track(
              'overlay_event_dismissed',
              properties: const <String, Object?>{
                'kind': 'music',
                'reason': 'paused',
              },
            ),
      );
      return;
    }

    final bool musicPlaying = event.kind == OrbitEventKind.music
        ? true
        : state.musicPlaying;

    state = state.copyWith(
      activeEvent: event,
      lastEvent: event,
      musicPlaying: musicPlaying,
      clearError: true,
    );

    unawaited(
      ref
          .read(orbitAnalyticsFacadeProvider)
          .track(
            'overlay_event_displayed',
            properties: <String, Object?>{
              'kind': event.kind.name,
              'display_ms': event.timing.displayMs,
              'queue_state': 'native_managed',
            },
          ),
    );
  }

  void _trackReceivedEvent(OrbitEventV2 event) {
    unawaited(
      ref
          .read(orbitAnalyticsFacadeProvider)
          .track(
            'overlay_event_received',
            properties: <String, Object?>{
              'kind': event.kind.name,
              'source_package': event.source.packageName,
              'priority': event.priority.name,
            },
          ),
    );
  }
}
