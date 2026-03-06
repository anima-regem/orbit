import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/orbit_event_v2.dart';
import '../../domain/orbit_settings.dart';
import '../../state/home_surface_controller.dart';
import '../../state/orbit_analytics_facade.dart';
import '../../state/overlay_calibration_controller.dart';
import '../../state/overlay_event_controller.dart';
import '../../state/profile_controller.dart';
import '../../state/orbit_settings_controller.dart';
import '../../widgets/orbit_ui.dart';
import '../overlay/orbit_source_visuals.dart';

class OrbitHomeScreen extends ConsumerStatefulWidget {
  const OrbitHomeScreen({super.key});

  @override
  ConsumerState<OrbitHomeScreen> createState() => _OrbitHomeScreenState();
}

class _OrbitHomeScreenState extends ConsumerState<OrbitHomeScreen> {
  bool _diagnosticsExpanded = false;
  bool _trackedView = false;

  @override
  Widget build(BuildContext context) {
    final HomeSurfaceState home = ref.watch(homeSurfaceStateProvider);

    if (!_trackedView) {
      _trackedView = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(
          ref.read(orbitAnalyticsFacadeProvider).track('dashboard_viewed'),
        );
      });
    }

    final List<Widget> sections = <Widget>[
      OrbitSectionCard(
        title: 'Live Card',
        subtitle: 'Native runtime state mirrored from orbitEventV2',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _RowValue(
              label: 'Overlay',
              value: home.settings.overlayEnabled ? 'Enabled' : 'Disabled',
            ),
            _RowValue(label: 'Active', value: home.activeLabel),
            _RowValue(
              label: 'Music',
              value: home.overlay.musicPlaying ? 'Playing' : 'Idle',
            ),
            _RowValue(
              label: 'Last event',
              value: _lastEventTime(home.latestEvent),
            ),
            const _RowValue(label: 'Queue', value: 'Native-managed'),
          ],
        ),
      ),
      OrbitSectionCard(
        title: 'Profiles',
        subtitle: 'Apply behavior presets optimized for your context',
        child: _ProfileStrip(
          activeProfile: home.settings.activeProfileId,
          onSelect: (OrbitProfileId profile) {
            unawaited(ref.read(profileControllerProvider).applyPreset(profile));
          },
        ),
      ),
      OrbitSectionCard(
        title: 'Diagnostics Controls',
        subtitle: 'Debug triggers for validating runtime behavior',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _diagnosticsExpanded = !_diagnosticsExpanded;
                });
              },
              icon: Icon(
                _diagnosticsExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
              ),
              label: Text(
                _diagnosticsExpanded ? 'Hide diagnostics' : 'Show diagnostics',
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              sizeCurve: Curves.easeOutCubic,
              crossFadeState: _diagnosticsExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 10),
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
                              .triggerNotification(),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      OrbitSectionCard(
        title: 'Now Live',
        subtitle: 'Real-time event preview',
        child: _NowLivePreview(event: home.latestEvent),
      ),
      OrbitSectionCard(
        title: 'Top Safe Lane',
        subtitle: 'Pinned below system UI by Android policy',
        child: Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'Orbit is anchored to a protected top lane for stable display.',
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: () {
                _openLaneCalibrationSheet(context);
              },
              child: const Text('Calibrate'),
            ),
          ],
        ),
      ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemBuilder: (BuildContext context, int index) {
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 220 + (index * 40)),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(begin: 0, end: 1),
          builder: (BuildContext context, double value, Widget? child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 10),
                child: child,
              ),
            );
          },
          child: sections[index],
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemCount: sections.length,
    );
  }

  Future<void> _openLaneCalibrationSheet(BuildContext context) async {
    await ref
        .read(overlayCalibrationControllerProvider)
        .trackOpened(source: 'home_safe_lane_chip');
    if (!context.mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return const _LaneCalibrationSheet();
      },
    );
  }

  String _lastEventTime(OrbitEventV2? event) {
    if (event == null) {
      return 'No events yet';
    }
    final DateTime now = DateTime.now();
    final Duration delta = now.difference(event.timing.receivedAt);
    if (delta.inSeconds < 5) {
      return 'Just now';
    }
    if (delta.inMinutes < 1) {
      return '${delta.inSeconds}s ago';
    }
    if (delta.inHours < 1) {
      return '${delta.inMinutes}m ago';
    }
    return '${delta.inHours}h ago';
  }
}

class _ProfileStrip extends StatelessWidget {
  const _ProfileStrip({required this.activeProfile, required this.onSelect});

  final OrbitProfileId activeProfile;
  final ValueChanged<OrbitProfileId> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _ProfileChip(
          label: 'Commute',
          selected: activeProfile == OrbitProfileId.commute,
          onTap: () => onSelect(OrbitProfileId.commute),
        ),
        _ProfileChip(
          label: 'Focus',
          selected: activeProfile == OrbitProfileId.focus,
          onTap: () => onSelect(OrbitProfileId.focus),
        ),
        _ProfileChip(
          label: 'Social',
          selected: activeProfile == OrbitProfileId.social,
          onTap: () => onSelect(OrbitProfileId.social),
        ),
        _ProfileChip(
          label: 'Custom',
          selected: activeProfile == OrbitProfileId.custom,
          onTap: () => onSelect(OrbitProfileId.custom),
        ),
      ],
    );
  }
}

class _ProfileChip extends StatefulWidget {
  const _ProfileChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ProfileChip> createState() => _ProfileChipState();
}

class _ProfileChipState extends State<_ProfileChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _pressed = true;
        });
      },
      onTapCancel: () {
        setState(() {
          _pressed = false;
        });
      },
      onTapUp: (_) {
        setState(() {
          _pressed = false;
        });
      },
      onTap: widget.onTap,
      child: AnimatedOpacity(
        duration: Duration(milliseconds: _pressed ? 90 : 120),
        curve: Curves.easeOutCubic,
        opacity: _pressed ? 0.72 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? const Color(0xFF0B69FF)
                : const Color(0xFFE9EDF6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: widget.selected ? Colors.white : const Color(0xFF3B4F6A),
            ),
          ),
        ),
      ),
    );
  }
}

class _NowLivePreview extends StatelessWidget {
  const _NowLivePreview({required this.event});

  final OrbitEventV2? event;

  @override
  Widget build(BuildContext context) {
    if (event == null) {
      return const Text('No live event yet.');
    }

    final OrbitSourceVisuals visuals = sourceVisualsForPackage(
      event!.source.packageName,
      event!.source.displayName,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: visuals.color.withValues(alpha: 0.24),
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
                  event!.content.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (event!.content.body != null)
                  Text(
                    event!.content.body!,
                    style: const TextStyle(color: Color(0xFFB9C6D8)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LaneCalibrationSheet extends ConsumerWidget {
  const _LaneCalibrationSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OrbitSettings settings =
        ref.watch(orbitSettingsControllerProvider).valueOrNull ??
        OrbitSettings.defaults();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Calibrate Top Safe Lane',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('Tight'),
                  selected: settings.lanePreset == OrbitLanePreset.tight,
                  onSelected: (_) {
                    unawaited(
                      ref
                          .read(overlayCalibrationControllerProvider)
                          .applyLanePreset(OrbitLanePreset.tight),
                    );
                  },
                ),
                ChoiceChip(
                  label: const Text('Balanced'),
                  selected: settings.lanePreset == OrbitLanePreset.balanced,
                  onSelected: (_) {
                    unawaited(
                      ref
                          .read(overlayCalibrationControllerProvider)
                          .applyLanePreset(OrbitLanePreset.balanced),
                    );
                  },
                ),
                ChoiceChip(
                  label: const Text('Relaxed'),
                  selected: settings.lanePreset == OrbitLanePreset.relaxed,
                  onSelected: (_) {
                    unawaited(
                      ref
                          .read(overlayCalibrationControllerProvider)
                          .applyLanePreset(OrbitLanePreset.relaxed),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Lane offset: ${settings.overlayOffsetYPx.toStringAsFixed(0)} px',
            ),
            Slider(
              min: -40,
              max: 80,
              divisions: 120,
              value: settings.overlayOffsetYPx,
              onChanged: (double value) {
                unawaited(
                  ref
                      .read(overlayCalibrationControllerProvider)
                      .setLaneOffset(value),
                );
              },
              onChangeEnd: (double value) {
                unawaited(
                  ref
                      .read(overlayCalibrationControllerProvider)
                      .saveCustomLaneOffset(value),
                );
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowValue extends StatelessWidget {
  const _RowValue({required this.label, required this.value});

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
