import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/orbit_installed_app.dart';
import 'orbit_analytics_facade.dart';
import 'orbit_settings_controller.dart';
import 'permission_controller.dart';

class NotificationAppSelectionState {
  const NotificationAppSelectionState({
    this.searchQuery = '',
    this.installedApps = const <OrbitInstalledApp>[],
    this.loading = false,
  });

  final String searchQuery;
  final List<OrbitInstalledApp> installedApps;
  final bool loading;

  List<OrbitInstalledApp> filteredApps() {
    final String query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return installedApps;
    }

    return installedApps.where((OrbitInstalledApp app) {
      return app.label.toLowerCase().contains(query) ||
          app.packageName.toLowerCase().contains(query);
    }).toList();
  }

  NotificationAppSelectionState copyWith({
    String? searchQuery,
    List<OrbitInstalledApp>? installedApps,
    bool? loading,
  }) {
    return NotificationAppSelectionState(
      searchQuery: searchQuery ?? this.searchQuery,
      installedApps: installedApps ?? this.installedApps,
      loading: loading ?? this.loading,
    );
  }
}

final notificationAppSelectionControllerProvider =
    NotifierProvider<
      NotificationAppSelectionController,
      NotificationAppSelectionState
    >(NotificationAppSelectionController.new);

class NotificationAppSelectionController
    extends Notifier<NotificationAppSelectionState> {
  @override
  NotificationAppSelectionState build() {
    Future<void>.microtask(refreshInstalledApps);
    return const NotificationAppSelectionState(loading: true);
  }

  Future<void> refreshInstalledApps() async {
    state = state.copyWith(loading: true);
    final List<OrbitInstalledApp> apps = await ref
        .read(orbitPermissionServiceProvider)
        .getInstalledApps();
    state = state.copyWith(installedApps: apps, loading: false);
  }

  void setSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  Future<void> toggleApp(String packageName, bool selected) async {
    final AsyncValue settingsValue = ref.read(orbitSettingsControllerProvider);
    final current = settingsValue.valueOrNull;
    if (current == null) {
      return;
    }

    final Set<String> next = current.selectedNotificationPackages.toSet();
    if (selected) {
      next.add(packageName.toLowerCase());
    } else {
      next.remove(packageName.toLowerCase());
    }

    await ref
        .read(orbitSettingsControllerProvider.notifier)
        .setSelectedNotificationPackages(next);

    await ref
        .read(orbitAnalyticsFacadeProvider)
        .track(
          'notification_app_toggled',
          properties: <String, Object?>{
            'source_package': packageName.toLowerCase(),
            'selected': selected,
          },
        );
  }
}
