import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/orbit_settings.dart';
import '../../models/orbit_installed_app.dart';
import '../../state/notification_app_selection_controller.dart';
import '../../state/orbit_analytics_facade.dart';
import '../../state/orbit_settings_controller.dart';
import '../../state/overlay_event_controller.dart';
import '../../widgets/orbit_ui.dart';

class OrbitSettingsScreen extends ConsumerWidget {
  const OrbitSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OrbitSettings settings =
        ref.watch(orbitSettingsControllerProvider).valueOrNull ??
        OrbitSettings.defaults();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: <Widget>[
        OrbitSectionCard(
          title: 'Overlay Behavior',
          subtitle:
              'Control native overlay visibility, persistence, and motion',
          child: Column(
            children: <Widget>[
              _SemanticSwitchTile(
                title: 'Enable overlay',
                onLabel: 'Overlay enabled',
                offLabel: 'Overlay disabled',
                value: settings.overlayEnabled,
                onChanged: (bool value) {
                  unawaited(
                    ref
                        .read(orbitSettingsControllerProvider.notifier)
                        .setOverlayEnabled(value),
                  );
                  _trackSettingChange(
                    ref,
                    key: 'overlay_enabled',
                    oldValue: settings.overlayEnabled,
                    newValue: value,
                  );
                },
              ),
              _SemanticSwitchTile(
                title: 'Enable music animation',
                onLabel: 'Music animation enabled',
                offLabel: 'Music animation disabled',
                value: settings.musicEnabled,
                onChanged: (bool value) {
                  unawaited(
                    ref
                        .read(orbitSettingsControllerProvider.notifier)
                        .setMusicEnabled(value),
                  );
                  _trackSettingChange(
                    ref,
                    key: 'music_enabled',
                    oldValue: settings.musicEnabled,
                    newValue: value,
                  );
                },
              ),
              _SemanticSwitchTile(
                title: 'Keep visible while music plays',
                onLabel: 'Persistent music mode',
                offLabel: 'Timed music mode',
                value: settings.musicPersistent,
                onChanged: (bool value) {
                  unawaited(
                    ref
                        .read(orbitSettingsControllerProvider.notifier)
                        .setMusicPersistent(value),
                  );
                  _trackSettingChange(
                    ref,
                    key: 'music_persistent',
                    oldValue: settings.musicPersistent,
                    newValue: value,
                  );
                },
              ),
              _SemanticSwitchTile(
                title: 'Enable dynamic theme',
                onLabel: 'Dynamic theme enabled',
                offLabel: 'Dynamic theme disabled',
                value: settings.dynamicThemeEnabled,
                onChanged: (bool value) {
                  unawaited(
                    ref
                        .read(orbitSettingsControllerProvider.notifier)
                        .setDynamicThemeEnabled(value),
                  );
                  _trackSettingChange(
                    ref,
                    key: 'dynamic_theme_enabled',
                    oldValue: settings.dynamicThemeEnabled,
                    newValue: value,
                  );
                },
              ),
              _SemanticSwitchTile(
                title: 'Reduced motion',
                onLabel: 'Reduced motion enabled',
                offLabel: 'Reduced motion disabled',
                value: settings.reducedMotionEnabled,
                onChanged: (bool value) {
                  unawaited(
                    ref
                        .read(orbitSettingsControllerProvider.notifier)
                        .setReducedMotionEnabled(value),
                  );
                  _trackSettingChange(
                    ref,
                    key: 'reduced_motion_enabled',
                    oldValue: settings.reducedMotionEnabled,
                    newValue: value,
                  );
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Display duration: ${settings.displaySeconds.toStringAsFixed(1)}s',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Slider(
                min: 3,
                max: 5,
                divisions: 8,
                value: settings.displaySeconds,
                label: '${settings.displaySeconds.toStringAsFixed(1)}s',
                onChanged: (double value) {
                  unawaited(
                    ref
                        .read(orbitSettingsControllerProvider.notifier)
                        .setDisplaySeconds(value),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OrbitSectionCard(
          title: 'Notification Trigger Apps',
          subtitle: 'Choose which apps can trigger overlay notifications',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${settings.selectedNotificationPackages.length} selected',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () {
                  _openNotificationAppSheet(context, ref);
                },
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Manage app filters'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OrbitSectionCard(
          title: 'Analytics & Diagnostics',
          subtitle: 'Privacy controls and runtime debug details',
          child: Column(
            children: <Widget>[
              _SemanticSwitchTile(
                title: 'Analytics enabled',
                onLabel: 'Analytics tracking enabled',
                offLabel: 'Analytics tracking disabled',
                value: settings.analyticsEnabled,
                onChanged: (bool value) {
                  unawaited(
                    ref
                        .read(orbitSettingsControllerProvider.notifier)
                        .setAnalyticsEnabled(value),
                  );
                  _trackSettingChange(
                    ref,
                    key: 'analytics_enabled',
                    oldValue: settings.analyticsEnabled,
                    newValue: value,
                  );
                },
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Consumer(
                  builder: (BuildContext context, WidgetRef ref, Widget? child) {
                    final OverlayEventState overlay = ref.watch(
                      overlayEventControllerProvider,
                    );
                    return Text(
                      'Active: ${overlay.activeEvent?.kind.name ?? 'idle'}\n'
                      'Queue: Native-managed\n'
                      'Channel: orbit/events · orbitEventV2\n'
                      'Config method: setOverlayConfigV2',
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _trackSettingChange(
    WidgetRef ref, {
    required String key,
    required Object? oldValue,
    required Object? newValue,
  }) {
    unawaited(
      ref
          .read(orbitAnalyticsFacadeProvider)
          .track(
            'settings_changed',
            properties: <String, Object?>{
              'setting_key': key,
              'old_value': oldValue,
              'new_value': newValue,
            },
          ),
    );
  }

  Future<void> _openNotificationAppSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return const _NotificationAppSelectionSheet();
      },
    );
  }
}

class _NotificationAppSelectionSheet extends ConsumerWidget {
  const _NotificationAppSelectionSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OrbitSettings settings =
        ref.watch(orbitSettingsControllerProvider).valueOrNull ??
        OrbitSettings.defaults();
    final NotificationAppSelectionState state = ref.watch(
      notificationAppSelectionControllerProvider,
    );

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Notification trigger apps',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              TextField(
                onChanged: (String value) {
                  ref
                      .read(notificationAppSelectionControllerProvider.notifier)
                      .setSearchQuery(value);
                },
                decoration: const InputDecoration(
                  hintText: 'Search installed apps',
                  prefixIcon: Icon(Icons.search_rounded),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  FilledButton.tonal(
                    onPressed: () {
                      unawaited(
                        ref
                            .read(
                              notificationAppSelectionControllerProvider
                                  .notifier,
                            )
                            .refreshInstalledApps(),
                      );
                    },
                    child: const Text('Reload apps'),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${settings.selectedNotificationPackages.length} selected',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x22000000)),
                  ),
                  child: state.loading
                      ? const Center(child: CircularProgressIndicator())
                      : _AppList(
                          apps: state.filteredApps(),
                          selectedPackages:
                              settings.selectedNotificationPackages,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppList extends ConsumerWidget {
  const _AppList({required this.apps, required this.selectedPackages});

  final List<OrbitInstalledApp> apps;
  final Set<String> selectedPackages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (apps.isEmpty) {
      return const Center(child: Text('No apps match your search.'));
    }

    return ListView.builder(
      itemCount: apps.length,
      itemBuilder: (BuildContext context, int index) {
        final OrbitInstalledApp app = apps[index];
        final String pkg = app.packageName.toLowerCase();
        final bool selected = selectedPackages.contains(pkg);

        return CheckboxListTile(
          value: selected,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(app.label.isEmpty ? app.packageName : app.label),
          subtitle: Text(
            '${app.isWorkProfile ? 'Work' : 'Personal'} · ${app.packageName}',
          ),
          onChanged: (bool? value) {
            final bool next = value ?? false;
            unawaited(
              ref
                  .read(notificationAppSelectionControllerProvider.notifier)
                  .toggleApp(pkg, next),
            );
            unawaited(
              ref
                  .read(orbitAnalyticsFacadeProvider)
                  .track(
                    'notification_app_toggled',
                    properties: <String, Object?>{
                      'source_package': pkg,
                      'selected': next,
                    },
                  ),
            );
          },
        );
      },
    );
  }
}

class _SemanticSwitchTile extends StatelessWidget {
  const _SemanticSwitchTile({
    required this.title,
    required this.onLabel,
    required this.offLabel,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String onLabel;
  final String offLabel;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(value ? onLabel : offLabel),
      value: value,
      onChanged: onChanged,
    );
  }
}
