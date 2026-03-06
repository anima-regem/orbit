# Orbit Lite

Orbit Lite is an Android-first Flutter app that shows a reactive top-lane
overlay for music playback and selected app notifications.

The app combines:
- Flutter UI and state management (Riverpod)
- Native Android listeners/services (Kotlin)
- A MethodChannel bridge (`orbit/permissions`, `orbit/events`)

## Current Product Surface

- Setup wizard (`SetupFlowScreen`) gated by required permissions:
  - Post notifications
  - Notification listener access
  - Overlay permission
  - Top safe lane calibration + profile selection
- Home (`OrbitHomeScreen`):
  - Live card (runtime status)
  - Profile strip (`Commute`, `Focus`, `Social`, `Custom`)
  - Diagnostics controls (debug triggers)
  - Top safe lane calibration entry
- Settings (`OrbitSettingsScreen`):
  - Basic pane: overlay/music behavior, display duration, app filters, analytics
  - Advanced pane: placement/depth/size tuning, dynamic theme, diagnostics, reset/setup actions

## Requirements

- Flutter SDK with Dart 3.10+ (project uses `sdk: ^3.10.1`)
- Android SDK + emulator/device
- Android platform support only in this repository (no iOS/web targets checked in)

## Run Locally

```bash
flutter pub get
flutter run
```

Optional: enable Segment analytics export by providing a write key:

```bash
flutter run --dart-define=SEGMENT_WRITE_KEY=YOUR_SEGMENT_WRITE_KEY
```

## Android Permissions Used

- `android.permission.POST_NOTIFICATIONS`
- `android.permission.SYSTEM_ALERT_WINDOW`
- `android.permission.BIND_NOTIFICATION_LISTENER_SERVICE` (service permission)
- `android.permission.FOREGROUND_SERVICE`
- `android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK`
- `android.permission.RECEIVE_BOOT_COMPLETED`

## Test Commands

```bash
flutter test
```

```bash
cd android && ./gradlew test
```

## Key Paths

```text
lib/orbit/features/                # onboarding, home, settings, shell
lib/orbit/state/                   # Riverpod controllers + orchestration
lib/orbit/platform/                # MethodChannel clients for native bridge
android/app/src/main/kotlin/com/example/orbit/
                                  # native services, bridge contracts, overlay manager
docs/analytics/orbit_events.md     # analytics taxonomy
docs/ux/orbit_interaction_spec.md  # interaction and motion spec
```
