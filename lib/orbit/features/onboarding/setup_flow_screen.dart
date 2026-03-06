import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/orbit_settings.dart';
import '../../platform/orbit_permission_service.dart';
import '../../state/orbit_analytics_facade.dart';
import '../../state/overlay_calibration_controller.dart';
import '../../state/permission_controller.dart';
import '../../state/profile_controller.dart';
import '../../state/orbit_settings_controller.dart';

class SetupFlowScreen extends ConsumerStatefulWidget {
  const SetupFlowScreen({super.key, this.onCompleted});

  final VoidCallback? onCompleted;

  @override
  ConsumerState<SetupFlowScreen> createState() => _SetupFlowScreenState();
}

class _SetupFlowScreenState extends ConsumerState<SetupFlowScreen> {
  final Set<String> _hapticsSent = <String>{};
  final PageController _pageController = PageController();
  int _stepIndex = 0;
  bool _startedTracked = false;
  OrbitProfileId _selectedProfile = OrbitProfileId.commute;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<OrbitPermissionStatus>>(
      permissionControllerProvider,
      (
        AsyncValue<OrbitPermissionStatus>? previous,
        AsyncValue<OrbitPermissionStatus> next,
      ) {
        final OrbitPermissionStatus? prev = previous?.valueOrNull;
        final OrbitPermissionStatus? current = next.valueOrNull;
        if (current == null) {
          return;
        }

        _handleStepTransition(
          key: 'post_notifications',
          wasGranted: prev?.postNotificationsGranted ?? false,
          nowGranted: current.postNotificationsGranted,
        );
        _handleStepTransition(
          key: 'notification_access',
          wasGranted: prev?.notificationAccessGranted ?? false,
          nowGranted: current.notificationAccessGranted,
        );
        _handleStepTransition(
          key: 'overlay_permission',
          wasGranted: prev?.overlayGranted ?? false,
          nowGranted: current.overlayGranted,
        );
      },
    );

    if (!_startedTracked) {
      _startedTracked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final analytics = ref.read(orbitAnalyticsFacadeProvider);
        unawaited(analytics.track('onboarding_started'));
      });
    }

    final OrbitPermissionStatus status =
        ref.watch(permissionControllerProvider).valueOrNull ??
        const OrbitPermissionStatus(
          postNotificationsGranted: false,
          notificationAccessGranted: false,
          overlayGranted: false,
          bridgeAvailable: true,
        );
    final OrbitSettings settings =
        ref.watch(orbitSettingsControllerProvider).valueOrNull ??
        OrbitSettings.defaults();

    final List<_WizardStep> steps = _buildSteps(status);
    final bool isFinalStep = _stepIndex == steps.length - 1;
    final _WizardStep current = steps[_stepIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Orbit'),
        automaticallyImplyLeading: Navigator.of(context).canPop(),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (_stepIndex + 1) / steps.length,
                    minHeight: 8,
                    color: const Color(0xFF0B69FF),
                    backgroundColor: const Color(0x1A0B69FF),
                  ),
                ),
                const SizedBox(height: 6),
                Text('Step ${_stepIndex + 1} of ${steps.length}'),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: steps.length,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (BuildContext context, int index) {
                return _WizardStepPage(
                  step: steps[index],
                  settings: settings,
                  selectedProfile: _selectedProfile,
                  onSelectProfile: (OrbitProfileId value) {
                    setState(() {
                      _selectedProfile = value;
                    });
                  },
                  onApplyLanePreset: (OrbitLanePreset preset) {
                    unawaited(
                      ref
                          .read(overlayCalibrationControllerProvider)
                          .applyLanePreset(preset),
                    );
                  },
                  onLaneOffsetChanged: (double value) {
                    unawaited(
                      ref
                          .read(overlayCalibrationControllerProvider)
                          .setLaneOffset(value),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                children: <Widget>[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: current.primaryEnabled
                          ? () {
                              unawaited(
                                _onPrimaryPressed(current, isFinalStep),
                              );
                            }
                          : null,
                      child: Text(current.primaryLabel),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        unawaited(_onSecondaryPressed(current));
                      },
                      child: Text(current.secondaryLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_WizardStep> _buildSteps(OrbitPermissionStatus status) {
    return <_WizardStep>[
      _WizardStep(
        key: 'post_notifications',
        title: 'Allow Post Notifications',
        description:
            'Grant runtime notifications so Orbit can surface listener state and setup updates.',
        helper: status.postNotificationsGranted
            ? 'Permission granted. Continue to the next step.'
            : 'If denied, tap grant again and allow notifications in system prompt.',
        completed: status.postNotificationsGranted,
        primaryLabel: status.postNotificationsGranted
            ? 'Continue'
            : 'Grant permission',
        secondaryLabel: 'I already enabled this',
        primaryEnabled: true,
        onPrimary: () async {
          final PermissionController controller = ref.read(
            permissionControllerProvider.notifier,
          );
          final OrbitAnalyticsFacade analytics = ref.read(
            orbitAnalyticsFacadeProvider,
          );
          final bool granted = await controller.requestPostNotifications();
          if (!mounted) {
            return;
          }
          unawaited(
            analytics.track(
              'permission_grant_result',
              properties: <String, Object?>{
                'permission_key': 'post_notifications',
                'granted': granted,
              },
            ),
          );
          await controller.refresh();
        },
      ),
      _WizardStep(
        key: 'notification_access',
        title: 'Enable Notification Access',
        description:
            'Allow Orbit to read selected app notifications and active media sessions.',
        helper: status.notificationAccessGranted
            ? 'Access granted. Continue to overlay permission.'
            : 'If denied, open notification access and enable Orbit listener.',
        completed: status.notificationAccessGranted,
        primaryLabel: status.notificationAccessGranted
            ? 'Continue'
            : 'Open settings',
        secondaryLabel: 'I already enabled this',
        primaryEnabled: true,
        onPrimary: () async {
          await ref
              .read(permissionControllerProvider.notifier)
              .openNotificationAccessSettings();
        },
      ),
      _WizardStep(
        key: 'overlay_permission',
        title: 'Allow Overlay Permission',
        description:
            'Required for native overlay display while you move across apps.',
        helper: status.overlayGranted
            ? 'Overlay permission granted. Continue to lane calibration.'
            : 'If denied, allow “Display over other apps” for Orbit.',
        completed: status.overlayGranted,
        primaryLabel: status.overlayGranted ? 'Continue' : 'Open settings',
        secondaryLabel: 'I already enabled this',
        primaryEnabled: true,
        onPrimary: () async {
          await ref
              .read(permissionControllerProvider.notifier)
              .openOverlaySettings();
        },
      ),
      _WizardStep(
        key: 'safe_lane',
        title: 'Calibrate Top Safe Lane',
        description:
            'Orbit is pinned below critical system UI. Choose a lane preset and offset.',
        helper:
            'Pick your startup profile and finish setup. You can recalibrate later in settings.',
        completed: status.allGranted,
        primaryLabel: 'Finish setup',
        secondaryLabel: 'Back',
        primaryEnabled: status.allGranted,
        onPrimary: () async {
          await ref
              .read(profileControllerProvider)
              .applyPreset(_selectedProfile, source: 'wizard_completion');
          await ref
              .read(orbitAnalyticsFacadeProvider)
              .track(
                'setup_wizard_completed',
                properties: <String, Object?>{
                  'selected_profile': _selectedProfile.value,
                },
              );
          if (!mounted) {
            return;
          }
          widget.onCompleted?.call();
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
      ),
    ];
  }

  Future<void> _onPrimaryPressed(_WizardStep current, bool isFinalStep) async {
    if (isFinalStep) {
      await current.onPrimary();
      return;
    }

    if (!current.completed) {
      await current.onPrimary();
      if (!mounted) {
        return;
      }
      await ref.read(permissionControllerProvider.notifier).refresh();
      return;
    }

    await _goToStep(_stepIndex + 1);
  }

  Future<void> _onSecondaryPressed(_WizardStep current) async {
    if (_stepIndex == 0) {
      await ref.read(permissionControllerProvider.notifier).refresh();
      return;
    }

    if (_stepIndex == 3) {
      await _goToStep(_stepIndex - 1);
      return;
    }

    await ref.read(permissionControllerProvider.notifier).refresh();
  }

  Future<void> _goToStep(int nextIndex) async {
    final int clamped = nextIndex.clamp(0, 3);
    if (clamped == _stepIndex) {
      return;
    }

    setState(() {
      _stepIndex = clamped;
    });
    await _pageController.animateToPage(
      clamped,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );

    if (clamped == 3) {
      await ref
          .read(overlayCalibrationControllerProvider)
          .trackOpened(source: 'wizard_step');
    }
  }

  Future<void> _handleStepTransition({
    required String key,
    required bool wasGranted,
    required bool nowGranted,
  }) async {
    if (wasGranted || !nowGranted || _hapticsSent.contains(key)) {
      return;
    }

    _hapticsSent.add(key);
    final OrbitAnalyticsFacade analytics = ref.read(
      orbitAnalyticsFacadeProvider,
    );
    await HapticFeedback.lightImpact();
    if (!mounted) {
      return;
    }
    await analytics.track(
      'onboarding_step_completed',
      properties: <String, Object?>{'step_key': key},
    );

    final int next = (_stepIndex + 1).clamp(0, 3);
    if (_stepIndex < 3) {
      await _goToStep(next);
    }
  }
}

class _WizardStep {
  const _WizardStep({
    required this.key,
    required this.title,
    required this.description,
    required this.helper,
    required this.completed,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.primaryEnabled,
    required this.onPrimary,
  });

  final String key;
  final String title;
  final String description;
  final String helper;
  final bool completed;
  final String primaryLabel;
  final String secondaryLabel;
  final bool primaryEnabled;
  final Future<void> Function() onPrimary;
}

class _WizardStepPage extends StatelessWidget {
  const _WizardStepPage({
    required this.step,
    required this.settings,
    required this.selectedProfile,
    required this.onSelectProfile,
    required this.onApplyLanePreset,
    required this.onLaneOffsetChanged,
  });

  final _WizardStep step;
  final OrbitSettings settings;
  final OrbitProfileId selectedProfile;
  final ValueChanged<OrbitProfileId> onSelectProfile;
  final ValueChanged<OrbitLanePreset> onApplyLanePreset;
  final ValueChanged<double> onLaneOffsetChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: <Widget>[
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: step.completed
                ? const Color(0x190DB55B)
                : const Color(0x120B69FF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: step.completed
                  ? const Color(0x330DB55B)
                  : const Color(0x220B69FF),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: animation,
                              child: child,
                            ),
                          );
                        },
                    child: step.completed
                        ? const Icon(
                            Icons.check_circle,
                            key: ValueKey<String>('done'),
                            color: Color(0xFF0DB55B),
                          )
                        : const Icon(
                            Icons.radio_button_unchecked,
                            key: ValueKey<String>('pending'),
                            color: Color(0xFF355070),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(step.description),
              const SizedBox(height: 8),
              Text(
                step.helper,
                style: const TextStyle(
                  color: Color(0xFF4C5E76),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (step.key == 'safe_lane') ...<Widget>[
          const SizedBox(height: 14),
          const Text(
            'Lane presets',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: <Widget>[
              ChoiceChip(
                label: const Text('Tight'),
                selected: settings.lanePreset == OrbitLanePreset.tight,
                onSelected: (_) {
                  onApplyLanePreset(OrbitLanePreset.tight);
                },
              ),
              ChoiceChip(
                label: const Text('Balanced'),
                selected: settings.lanePreset == OrbitLanePreset.balanced,
                onSelected: (_) {
                  onApplyLanePreset(OrbitLanePreset.balanced);
                },
              ),
              ChoiceChip(
                label: const Text('Relaxed'),
                selected: settings.lanePreset == OrbitLanePreset.relaxed,
                onSelected: (_) {
                  onApplyLanePreset(OrbitLanePreset.relaxed);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Lane offset',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          Slider(
            min: -40,
            max: 80,
            divisions: 120,
            value: settings.overlayOffsetYPx.clamp(-40, 80).toDouble(),
            onChanged: onLaneOffsetChanged,
          ),
          const SizedBox(height: 8),
          const Text(
            'Initial profile',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _ProfileChoice(
                label: 'Commute',
                selected: selectedProfile == OrbitProfileId.commute,
                onTap: () => onSelectProfile(OrbitProfileId.commute),
              ),
              _ProfileChoice(
                label: 'Focus',
                selected: selectedProfile == OrbitProfileId.focus,
                onTap: () => onSelectProfile(OrbitProfileId.focus),
              ),
              _ProfileChoice(
                label: 'Social',
                selected: selectedProfile == OrbitProfileId.social,
                onTap: () => onSelectProfile(OrbitProfileId.social),
              ),
              _ProfileChoice(
                label: 'Custom',
                selected: selectedProfile == OrbitProfileId.custom,
                onTap: () => onSelectProfile(OrbitProfileId.custom),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ProfileChoice extends StatelessWidget {
  const _ProfileChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
