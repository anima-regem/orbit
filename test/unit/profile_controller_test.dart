import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/orbit/domain/orbit_settings.dart';
import 'package:orbit/orbit/platform/orbit_permission_service.dart';
import 'package:orbit/orbit/state/orbit_settings_controller.dart';
import 'package:orbit/orbit/state/orbit_settings_repository.dart';
import 'package:orbit/orbit/state/permission_controller.dart';
import 'package:orbit/orbit/state/profile_controller.dart';

void main() {
  test('applying focus profile updates settings preset fields', () async {
    final _MemorySettingsRepository repository = _MemorySettingsRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        orbitSettingsRepositoryProvider.overrideWithValue(repository),
        permissionControllerProvider.overrideWith(
          () =>
              _TestPermissionController(const OrbitPermissionStatus.granted()),
        ),
      ],
    );

    addTearDown(container.dispose);

    await container.read(orbitSettingsControllerProvider.future);

    await container
        .read(profileControllerProvider)
        .applyPreset(OrbitProfileId.focus);

    final OrbitSettings settings = container
        .read(orbitSettingsControllerProvider)
        .valueOrNull!;

    expect(settings.activeProfileId, OrbitProfileId.focus);
    expect(settings.reducedMotionEnabled, isTrue);
    expect(settings.musicPersistent, isFalse);
    expect(settings.displaySeconds, closeTo(3.2, 0.001));
    expect(
      settings.selectedNotificationPackages.contains('com.slack.android'),
      isTrue,
    );
  });
}

class _MemorySettingsRepository extends OrbitSettingsRepository {
  OrbitSettings _current = OrbitSettings.defaults();

  @override
  Future<OrbitSettings> load() async {
    return _current;
  }

  @override
  Future<void> save(OrbitSettings settings) async {
    _current = settings;
  }
}

class _TestPermissionController extends PermissionController {
  _TestPermissionController(this.status);

  final OrbitPermissionStatus status;

  @override
  Future<OrbitPermissionStatus> build() async {
    return status;
  }
}
