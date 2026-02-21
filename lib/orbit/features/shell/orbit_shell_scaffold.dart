import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/orbit_settings.dart';
import '../../platform/orbit_permission_service.dart';
import '../../state/orbit_analytics_facade.dart';
import '../../state/orbit_settings_controller.dart';
import '../../state/permission_controller.dart';
import '../dashboard/orbit_dashboard_screen.dart';
import '../onboarding/setup_flow_screen.dart';
import '../settings/orbit_settings_screen.dart';

class OrbitShellScaffold extends ConsumerStatefulWidget {
  const OrbitShellScaffold({super.key});

  @override
  ConsumerState<OrbitShellScaffold> createState() => _OrbitShellScaffoldState();
}

class _OrbitShellScaffoldState extends ConsumerState<OrbitShellScaffold> {
  int _index = 0;
  bool _initialConfigSynced = false;

  @override
  Widget build(BuildContext context) {
    final OrbitSettings? settings = ref
        .watch(orbitSettingsControllerProvider)
        .valueOrNull;

    if (settings != null && !_initialConfigSynced) {
      _initialConfigSynced = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_syncConfigToNative(settings));
      });
    }

    ref.listen<AsyncValue<OrbitSettings>>(orbitSettingsControllerProvider, (
      AsyncValue<OrbitSettings>? previous,
      AsyncValue<OrbitSettings> next,
    ) {
      final OrbitSettings? settings = next.valueOrNull;
      if (settings == null) {
        return;
      }

      unawaited(_syncConfigToNative(settings));
    });

    final OrbitPermissionStatus permission =
        ref.watch(permissionControllerProvider).valueOrNull ??
        const OrbitPermissionStatus(
          postNotificationsGranted: false,
          notificationAccessGranted: false,
          overlayGranted: false,
          bridgeAvailable: true,
        );

    final bool showSetup = !permission.allGranted;

    final List<({String label, IconData icon, Widget page})> destinations =
        <({String label, IconData icon, Widget page})>[
          if (showSetup)
            (
              label: 'Setup',
              icon: Icons.verified_user_rounded,
              page: const SetupFlowScreen(),
            ),
          (
            label: 'Dashboard',
            icon: Icons.dashboard_rounded,
            page: const OrbitDashboardScreen(),
          ),
          (
            label: 'Settings',
            icon: Icons.tune_rounded,
            page: const OrbitSettingsScreen(),
          ),
        ];

    if (_index >= destinations.length) {
      _index = destinations.length - 1;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Orbit Lite'), centerTitle: false),
      body: IndexedStack(
        index: _index,
        children: destinations
            .map(
              (({String label, IconData icon, Widget page}) item) => item.page,
            )
            .toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) {
          setState(() {
            _index = value;
          });
        },
        destinations: destinations
            .map(
              (({String label, IconData icon, Widget page}) item) =>
                  NavigationDestination(
                    icon: Icon(item.icon),
                    label: item.label,
                  ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _syncConfigToNative(OrbitSettings settings) async {
    final bool ok = await ref
        .read(orbitPermissionServiceProvider)
        .setOverlayConfigV2(settings);
    if (!ok) {
      await ref
          .read(orbitAnalyticsFacadeProvider)
          .track(
            'overlay_error',
            properties: const <String, Object?>{
              'stage': 'setOverlayConfigV2',
              'message': 'Native config sync failed',
            },
          );
    }
  }
}
