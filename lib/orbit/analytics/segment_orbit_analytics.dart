import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'orbit_analytics.dart';

class SegmentOrbitAnalytics implements OrbitAnalytics {
  SegmentOrbitAnalytics({required this.writeKey});

  final String writeKey;

  @override
  Future<void> track({
    required String event,
    required String sessionId,
    required Map<String, Object?> properties,
  }) async {
    final Uri uri = Uri.parse('https://api.segment.io/v1/track');
    final HttpClient client = HttpClient();

    try {
      final HttpClientRequest request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      final String basic = base64Encode(utf8.encode('$writeKey:'));
      request.headers.set(HttpHeaders.authorizationHeader, 'Basic $basic');

      final Map<String, Object?> payload = <String, Object?>{
        'event': event,
        'anonymousId': sessionId,
        'properties': properties,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };

      request.add(utf8.encode(jsonEncode(payload)));
      final HttpClientResponse response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('Segment track failed for $event: ${response.statusCode}');
      }
    } on Object catch (error) {
      debugPrint('Segment track error for $event: $error');
    } finally {
      client.close(force: true);
    }
  }
}
