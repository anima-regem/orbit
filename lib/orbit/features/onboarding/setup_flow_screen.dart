import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/orbit_permission_service.dart';
import '../../state/orbit_analytics_facade.dart';
import '../../state/permission_controller.dart';
import '../../widgets/orbit_ui.dart';

class SetupFlowScreen extends ConsumerStatefulWidget {
  const SetupFlowScreen({super.key});

  @override
  ConsumerState<SetupFlowScreen> createState() => _SetupFlowScreenState();
}

class _SetupFlowScreenState extends ConsumerState<SetupFlowScreen> {
  final Set<String> _hapticsSent = <String>{};
  bool _startedTracked = false;

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

    final AsyncValue<OrbitPermissionStatus> permissionAsync = ref.watch(
      permissionControllerProvider,
    );

    return permissionAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) {
        return Center(child: Text('Unable to load permissions: $error'));
      },
      data: (OrbitPermissionStatus status) {
        final double progress = status.grantedCount / 3;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: <Widget>[
            OrbitSectionCard(
              title: 'Setup Orbit',
              subtitle:
                  'Complete all three steps to enable live music and notification overlays.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      color: const Color(0xFF0B69FF),
                      backgroundColor: const Color(0x1A0B69FF),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${status.grantedCount}/3 complete'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SetupStepCard(
              stepIndex: 1,
              title: 'Allow Post Notifications',
              description:
                  'Required to show Orbit listener service state and onboarding updates.',
              granted: status.postNotificationsGranted,
              actionLabel: 'Grant permission',
              onPrimaryAction: () async {
                final permissionController = ref.read(
                  permissionControllerProvider.notifier,
                );
                final analytics = ref.read(orbitAnalyticsFacadeProvider);
                final bool granted = await permissionController
                    .requestPostNotifications();
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
              },
              onSecondaryAction: () {
                unawaited(
                  ref.read(permissionControllerProvider.notifier).refresh(),
                );
              },
              secondaryLabel: 'Refresh status',
            ),
            const SizedBox(height: 12),
            _SetupStepCard(
              stepIndex: 2,
              title: 'Enable Notification Access',
              description:
                  'Lets Orbit read selected app notifications and media sessions.',
              granted: status.notificationAccessGranted,
              actionLabel: 'Open notification access',
              onPrimaryAction: () {
                unawaited(
                  ref
                      .read(permissionControllerProvider.notifier)
                      .openNotificationAccessSettings(),
                );
              },
              onSecondaryAction: () {
                unawaited(
                  ref.read(permissionControllerProvider.notifier).refresh(),
                );
              },
              secondaryLabel: 'I enabled it',
            ),
            const SizedBox(height: 12),
            _SetupStepCard(
              stepIndex: 3,
              title: 'Allow Overlay Permission',
              description:
                  'Required for background native overlay while the app is not foregrounded.',
              granted: status.overlayGranted,
              actionLabel: 'Open overlay settings',
              onPrimaryAction: () {
                unawaited(
                  ref
                      .read(permissionControllerProvider.notifier)
                      .openOverlaySettings(),
                );
              },
              onSecondaryAction: () {
                unawaited(
                  ref.read(permissionControllerProvider.notifier).refresh(),
                );
              },
              secondaryLabel: 'I enabled it',
            ),
            const SizedBox(height: 12),
            OrbitSectionCard(
              title: status.allGranted ? 'Setup complete' : 'Need help?',
              child: Text(
                status.allGranted
                    ? 'All required permissions are granted. Orbit is ready.'
                    : 'If a permission remains disabled, use the step action and return to tap refresh.',
              ),
            ),
          ],
        );
      },
    );
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
    final analytics = ref.read(orbitAnalyticsFacadeProvider);
    await HapticFeedback.lightImpact();
    if (!mounted) {
      return;
    }
    await analytics.track(
      'onboarding_step_completed',
      properties: <String, Object?>{'step_key': key},
    );
  }
}

class _SetupStepCard extends StatelessWidget {
  const _SetupStepCard({
    required this.stepIndex,
    required this.title,
    required this.description,
    required this.granted,
    required this.actionLabel,
    required this.onPrimaryAction,
    required this.secondaryLabel,
    required this.onSecondaryAction,
  });

  final int stepIndex;
  final String title;
  final String description;
  final bool granted;
  final String actionLabel;
  final VoidCallback onPrimaryAction;
  final String secondaryLabel;
  final VoidCallback onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return OrbitSectionCard(
      title: 'Step $stepIndex · $title',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: granted ? const Color(0x190DB55B) : const Color(0x120B69FF),
          border: Border.all(
            color: granted ? const Color(0x330DB55B) : const Color(0x220B69FF),
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
                  child: granted
                      ? const Icon(
                          Icons.check_circle,
                          key: ValueKey('granted'),
                          color: Color(0xFF0DB55B),
                        )
                      : const Icon(
                          Icons.radio_button_unchecked,
                          key: ValueKey('pending'),
                          color: Color(0xFF355070),
                        ),
                ),
                const SizedBox(width: 8),
                Text(
                  granted ? 'Completed' : 'Pending',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: granted
                        ? const Color(0xFF0A8F4A)
                        : const Color(0xFF2D425E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: onPrimaryAction,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(actionLabel),
                ),
                OutlinedButton(
                  onPressed: onSecondaryAction,
                  child: Text(secondaryLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
