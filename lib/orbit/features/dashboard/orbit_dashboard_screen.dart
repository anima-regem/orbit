import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/orbit_event_v2.dart';
import '../../state/orbit_analytics_facade.dart';
import '../../state/orbit_settings_controller.dart';
import '../../state/overlay_event_controller.dart';
import '../../widgets/orbit_ui.dart';
import '../overlay/orbit_source_visuals.dart';

class OrbitDashboardScreen extends ConsumerWidget {
  const OrbitDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OverlayEventState overlay = ref.watch(overlayEventControllerProvider);
    final settings = ref.watch(orbitSettingsControllerProvider).valueOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: <Widget>[
        OrbitSectionCard(
          title: 'Live Status',
          subtitle: 'Native overlay runtime status from orbitEventV2 stream',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _StatusRow(
                label: 'Overlay',
                value: settings?.overlayEnabled == true
                    ? 'Enabled'
                    : 'Disabled',
              ),
              _StatusRow(
                label: 'Music mode',
                value: settings?.musicPersistent == true
                    ? 'Persistent while playing'
                    : 'Timed',
              ),
              _StatusRow(
                label: 'Active',
                value: _activeLabel(overlay.activeEvent),
              ),
              const _StatusRow(label: 'Queue', value: 'Native-managed'),
              _StatusRow(
                label: 'MethodChannel',
                value: 'orbit/events · orbitEventV2',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OrbitSectionCard(
          title: 'Quick Actions',
          subtitle: 'Trigger native debug events through orbit/permissions',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OrbitActionButton(
                icon: Icons.play_arrow_rounded,
                label: 'Start Music',
                onPressed: () {
                  unawaited(
                    ref
                        .read(overlayEventControllerProvider.notifier)
                        .triggerMusicStart(),
                  );
                },
              ),
              OrbitActionButton(
                icon: Icons.skip_next_rounded,
                label: 'Track Change',
                onPressed: () {
                  unawaited(
                    ref
                        .read(overlayEventControllerProvider.notifier)
                        .triggerTrackChange(),
                  );
                },
              ),
              OrbitActionButton(
                icon: Icons.notifications_active_rounded,
                label: 'Test Notification',
                onPressed: () {
                  unawaited(
                    ref
                        .read(overlayEventControllerProvider.notifier)
                        .triggerNotification(
                          packageName: 'com.instagram.android',
                          sourceName: 'Instagram',
                          title: 'Instagram DM',
                          body: 'New message from Alex',
                        ),
                  );
                },
              ),
              OrbitActionButton(
                icon: Icons.flash_on_rounded,
                label: 'Burst Test',
                onPressed: () {
                  unawaited(
                    ref
                        .read(overlayEventControllerProvider.notifier)
                        .triggerBurst(),
                  );
                },
              ),
              OrbitActionButton(
                icon: Icons.pause_rounded,
                label: 'Pause Music',
                onPressed: () {
                  unawaited(
                    ref
                        .read(overlayEventControllerProvider.notifier)
                        .triggerMusicPause(),
                  );
                },
              ),
              OrbitActionButton(
                icon: Icons.swap_vertical_circle_rounded,
                label: 'Music + Notification',
                onPressed: () {
                  unawaited(
                    ref
                        .read(overlayEventControllerProvider.notifier)
                        .triggerMusicAndNotification(),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OrbitSectionCard(
          title: 'Now Live',
          subtitle: 'Latest event from native stream telemetry',
          child: _NowLivePreview(
            activeEvent: overlay.activeEvent,
            lastEvent: overlay.lastEvent,
          ),
        ),
      ],
    );
  }

  String _activeLabel(OrbitEventV2? event) {
    if (event == null) {
      return 'Idle';
    }
    if (event.kind == OrbitEventKind.music) {
      return 'Music · ${event.content.title}';
    }
    if (event.kind == OrbitEventKind.notification) {
      return 'Notification · ${event.content.title}';
    }
    return 'Idle · Music paused';
  }
}

class _NowLivePreview extends ConsumerStatefulWidget {
  const _NowLivePreview({required this.activeEvent, required this.lastEvent});

  final OrbitEventV2? activeEvent;
  final OrbitEventV2? lastEvent;

  @override
  ConsumerState<_NowLivePreview> createState() => _NowLivePreviewState();
}

class _NowLivePreviewState extends ConsumerState<_NowLivePreview> {
  bool _tracked = false;

  @override
  Widget build(BuildContext context) {
    if (!_tracked) {
      _tracked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          ref.read(orbitAnalyticsFacadeProvider).track('dashboard_viewed'),
        );
      });
    }

    final OrbitEventV2? event = widget.activeEvent ?? widget.lastEvent;

    if (event == null) {
      return const Text(
        'No live event yet. Trigger a quick action to preview runtime state.',
      );
    }

    final OrbitSourceVisuals visuals = sourceVisualsForPackage(
      event.source.packageName,
      event.source.displayName,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: visuals.color.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Icon(visuals.icon, color: visuals.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  event.content.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (event.content.body != null)
                  Text(
                    event.content.body!,
                    style: const TextStyle(color: Color(0xFFB9C6D8)),
                  ),
                const SizedBox(height: 6),
                Text(
                  'Source: ${visuals.name} · Queue: Native-managed',
                  style: const TextStyle(
                    color: Color(0xFF8DA0B8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF5A687C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
