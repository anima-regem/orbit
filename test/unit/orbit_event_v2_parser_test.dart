import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/orbit/domain/orbit_event_v2.dart';

void main() {
  test('parses valid v2 notification payload', () {
    final OrbitEventV2? event = OrbitEventV2.tryParse(<String, Object?>{
      'schemaVersion': 2,
      'eventId': 'evt-1',
      'kind': 'notification',
      'sourcePackage': 'com.instagram.android',
      'sourceName': 'Instagram',
      'title': 'DM',
      'body': 'New message',
      'displayMs': 4200,
      'priority': 'high',
      'timestampMs': DateTime.now().millisecondsSinceEpoch,
    });

    expect(event, isNotNull);
    expect(event!.kind, OrbitEventKind.notification);
    expect(event.priority, OrbitEventPriority.high);
    expect(event.timing.displayMs, 4200);
  });

  test('rejects invalid schema', () {
    final OrbitEventV2? event = OrbitEventV2.tryParse(<String, Object?>{
      'schemaVersion': 1,
      'eventId': 'evt-1',
      'kind': 'notification',
      'sourcePackage': 'com.instagram.android',
      'title': 'DM',
      'displayMs': 4200,
      'priority': 'high',
      'timestampMs': DateTime.now().millisecondsSinceEpoch,
    });

    expect(event, isNull);
  });

  test('clamps invalid display duration', () {
    final OrbitEventV2? event = OrbitEventV2.tryParse(<String, Object?>{
      'schemaVersion': 2,
      'eventId': 'evt-1',
      'kind': 'music',
      'sourcePackage': 'com.spotify.music',
      'title': 'Track',
      'displayMs': 12000,
      'priority': 'normal',
      'timestampMs': DateTime.now().millisecondsSinceEpoch,
    });

    expect(event, isNotNull);
    expect(event!.timing.displayMs, 6000);
  });
}
