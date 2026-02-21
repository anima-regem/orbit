import 'dart:convert';
import 'dart:typed_data';

enum OrbitEventKind { music, notification, musicPaused }

enum OrbitEventPriority { high, normal }

class OrbitEventSource {
  const OrbitEventSource({required this.packageName, this.displayName});

  final String packageName;
  final String? displayName;
}

class OrbitEventContent {
  const OrbitEventContent({
    required this.title,
    this.subtitle,
    this.body,
    this.trackChange = false,
    this.albumArtBytes,
  });

  final String title;
  final String? subtitle;
  final String? body;
  final bool trackChange;
  final Uint8List? albumArtBytes;
}

class OrbitEventTiming {
  const OrbitEventTiming({required this.displayMs, required this.receivedAt});

  final int displayMs;
  final DateTime receivedAt;
}

class OrbitEventV2 {
  const OrbitEventV2({
    required this.eventId,
    required this.kind,
    required this.source,
    required this.content,
    required this.timing,
    required this.priority,
  });

  final String eventId;
  final OrbitEventKind kind;
  final OrbitEventSource source;
  final OrbitEventContent content;
  final OrbitEventTiming timing;
  final OrbitEventPriority priority;

  bool get isMusic => kind == OrbitEventKind.music;

  bool get isNotification => kind == OrbitEventKind.notification;

  static OrbitEventV2? tryParse(Map<dynamic, dynamic> raw) {
    int? toInt(dynamic value) {
      if (value is int) {
        return value;
      }
      if (value is String) {
        return int.tryParse(value);
      }
      return null;
    }

    if (toInt(raw['schemaVersion']) != 2) {
      return null;
    }

    final String eventId = (raw['eventId']?.toString() ?? '').trim();
    if (eventId.isEmpty) {
      return null;
    }

    final OrbitEventKind? kind = switch (raw['kind']?.toString()) {
      'music' => OrbitEventKind.music,
      'notification' => OrbitEventKind.notification,
      'musicPaused' => OrbitEventKind.musicPaused,
      _ => null,
    };

    if (kind == null) {
      return null;
    }

    final OrbitEventPriority priority = switch (raw['priority']?.toString()) {
      'high' => OrbitEventPriority.high,
      _ => OrbitEventPriority.normal,
    };

    final int timestampMs =
        toInt(raw['timestampMs']) ?? DateTime.now().millisecondsSinceEpoch;

    if (kind == OrbitEventKind.musicPaused) {
      return OrbitEventV2(
        eventId: eventId,
        kind: kind,
        source: const OrbitEventSource(packageName: 'system'),
        content: const OrbitEventContent(title: 'Paused'),
        timing: OrbitEventTiming(
          displayMs: 2000,
          receivedAt: DateTime.fromMillisecondsSinceEpoch(timestampMs),
        ),
        priority: priority,
      );
    }

    final String sourcePackage = (raw['sourcePackage']?.toString() ?? '')
        .trim()
        .toLowerCase();
    final String title = (raw['title']?.toString() ?? '').trim();
    final int displayMs = (toInt(raw['displayMs']) ?? 4000).clamp(2000, 6000);

    if (sourcePackage.isEmpty || title.isEmpty) {
      return null;
    }

    final String? artBase64 = raw['albumArtBase64']?.toString();
    final Uint8List? bytes = switch (artBase64) {
      String value when value.isNotEmpty => _tryDecodeBase64(value),
      _ => null,
    };

    return OrbitEventV2(
      eventId: eventId,
      kind: kind,
      source: OrbitEventSource(
        packageName: sourcePackage,
        displayName: raw['sourceName']?.toString(),
      ),
      content: OrbitEventContent(
        title: title,
        subtitle: raw['subtitle']?.toString(),
        body: raw['body']?.toString(),
        trackChange: raw['trackChange'] == true,
        albumArtBytes: bytes,
      ),
      timing: OrbitEventTiming(
        displayMs: displayMs,
        receivedAt: DateTime.fromMillisecondsSinceEpoch(timestampMs),
      ),
      priority: priority,
    );
  }

  static Uint8List? _tryDecodeBase64(String raw) {
    try {
      return base64Decode(raw);
    } on FormatException {
      return null;
    }
  }
}
