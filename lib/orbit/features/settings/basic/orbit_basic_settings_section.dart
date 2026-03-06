import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/orbit_settings.dart';
import '../../../models/orbit_installed_app.dart';
import '../../../state/notification_app_selection_controller.dart';
import '../../../state/orbit_analytics_facade.dart';
import '../../../state/orbit_settings_controller.dart';
import '../../../widgets/orbit_ui.dart';

class OrbitBasicSettingsSection extends ConsumerWidget {
  const OrbitBasicSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OrbitSettings settings =
        ref.watch(orbitSettingsControllerProvider).valueOrNull ??
        OrbitSettings.defaults();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: <Widget>[
        OrbitSectionCard(
          title: 'Basic Behavior',
          subtitle: 'Daily controls for overlay and motion',
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
                title: 'Enable music mode',
                onLabel: 'Music mode enabled',
                offLabel: 'Music mode disabled',
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
                  _openNotificationAppSheet(context);
                },
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Manage app filters'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OrbitSectionCard(
          title: 'Privacy',
          subtitle: 'Analytics collection preferences',
          child: _SemanticSwitchTile(
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
        ),
      ],
    );
  }

  Future<void> _openNotificationAppSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return const _NotificationAppSelectionSheet();
      },
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
                    border: Border.all(color: const Color(0x18000000)),
                  ),
                  child: state.loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: state.filteredApps().length,
                          itemBuilder: (BuildContext context, int index) {
                            final OrbitInstalledApp app = state
                                .filteredApps()[index];
                            final bool selected = settings
                                .selectedNotificationPackages
                                .contains(app.packageName.toLowerCase());

                            return CheckboxListTile(
                              dense: true,
                              title: Text(app.label),
                              subtitle: Text(
                                app.packageName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              value: selected,
                              onChanged: (bool? value) {
                                if (value == null) {
                                  return;
                                }
                                unawaited(
                                  ref
                                      .read(
                                        notificationAppSelectionControllerProvider
                                            .notifier,
                                      )
                                      .toggleApp(app.packageName, value),
                                );
                              },
                            );
                          },
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title),
      subtitle: Text(value ? onLabel : offLabel),
      trailing: Switch(value: value, onChanged: onChanged),
      onTap: () {
        onChanged(!value);
      },
    );
  }
}
