import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/orbit_settings.dart';
import '../../../state/orbit_analytics_facade.dart';
import '../../../state/orbit_settings_controller.dart';
import '../../../state/overlay_event_controller.dart';
import '../../../widgets/orbit_ui.dart';

class OrbitAdvancedSettingsSection extends ConsumerWidget {
  const OrbitAdvancedSettingsSection({super.key, required this.onReRunSetup});

  final VoidCallback onReRunSetup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OrbitSettings settings =
        ref.watch(orbitSettingsControllerProvider).valueOrNull ??
        OrbitSettings.defaults();
    final OverlayEventState overlay = ref.watch(overlayEventControllerProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: <Widget>[
        OrbitSectionCard(
          title: 'Placement & Depth',
          subtitle:
              'Adjust native top safe lane position, compact size, and depth emphasis',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Lane preset',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  ChoiceChip(
                    label: const Text('Tight'),
                    selected: settings.lanePreset == OrbitLanePreset.tight,
                    onSelected: (_) {
                      unawaited(
                        ref
                            .read(orbitSettingsControllerProvider.notifier)
                            .setLanePreset(OrbitLanePreset.tight),
                      );
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Balanced'),
                    selected: settings.lanePreset == OrbitLanePreset.balanced,
                    onSelected: (_) {
                      unawaited(
                        ref
                            .read(orbitSettingsControllerProvider.notifier)
                            .setLanePreset(OrbitLanePreset.balanced),
                      );
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Relaxed'),
                    selected: settings.lanePreset == OrbitLanePreset.relaxed,
                    onSelected: (_) {
                      unawaited(
                        ref
                            .read(orbitSettingsControllerProvider.notifier)
                            .setLanePreset(OrbitLanePreset.relaxed),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Lane offset Y: ${settings.overlayOffsetYPx.toStringAsFixed(0)} px',
              ),
              Slider(
                min: -80,
                max: 160,
                divisions: 240,
                value: settings.overlayOffsetYPx,
                onChanged: (double value) {
                  unawaited(
                    ref
                        .read(orbitSettingsControllerProvider.notifier)
                        .setOffsetY(value),
                  );
                },
              ),
              Text(
                'Horizontal offset: ${settings.overlayOffsetXPx.toStringAsFixed(0)} px',
              ),
              Slider(
                min: -120,
                max: 120,
                divisions: 240,
                value: settings.overlayOffsetXPx,
                onChanged: (double value) {
                  unawaited(
                    ref
                        .read(orbitSettingsControllerProvider.notifier)
                        .setOffsetX(value),
                  );
                },
              ),
              Text(
                'Depth emphasis: ${settings.overlayZAxisPx.toStringAsFixed(0)} px',
              ),
              Slider(
                min: 0,
                max: 120,
                divisions: 120,
                value: settings.overlayZAxisPx,
                onChanged: (double value) {
                  unawaited(
                    ref
                        .read(orbitSettingsControllerProvider.notifier)
                        .setZAxis(value),
                  );
                },
              ),
              Text(
                'Compact width: ${(settings.overlayWidthFactor * 100).toStringAsFixed(0)}%',
              ),
              Slider(
                min: 0.35,
                max: 0.8,
                divisions: 45,
                value: settings.overlayWidthFactor,
                onChanged: (double value) {
                  unawaited(
                    ref
                        .read(orbitSettingsControllerProvider.notifier)
                        .setWidthFactor(value),
                  );
                },
              ),
              Text(
                'Compact height: ${settings.overlayCompactHeightDp.toStringAsFixed(0)} dp',
              ),
              Slider(
                min: 38,
                max: 88,
                divisions: 50,
                value: settings.overlayCompactHeightDp,
                onChanged: (double value) {
                  unawaited(
                    ref
                        .read(orbitSettingsControllerProvider.notifier)
                        .setCompactHeight(value),
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
            ],
          ),
        ),
        const SizedBox(height: 12),
        OrbitSectionCard(
          title: 'Diagnostics',
          subtitle: 'Runtime bridge health and debug state',
          child: Text(
            'Active: ${overlay.activeEvent?.kind.name ?? 'idle'}\n'
            'Music playing: ${overlay.musicPlaying}\n'
            'Queue: Native-managed\n'
            'Channel: orbit/events · orbitEventV2\n'
            'Config method: setOverlayConfigV2',
          ),
        ),
        const SizedBox(height: 12),
        OrbitSectionCard(
          title: 'Setup & Resets',
          subtitle: 'Recovery actions for onboarding and customization',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: onReRunSetup,
                icon: const Icon(Icons.rocket_launch_rounded),
                label: const Text('Re-run setup wizard'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  unawaited(
                    ref
                        .read(orbitSettingsControllerProvider.notifier)
                        .resetPlacement(),
                  );
                },
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reset placement & depth'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  unawaited(
                    ref
                        .read(orbitSettingsControllerProvider.notifier)
                        .setActiveProfileId(OrbitProfileId.custom),
                  );
                },
                icon: const Icon(Icons.person_rounded),
                label: const Text('Set profile to Custom'),
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
