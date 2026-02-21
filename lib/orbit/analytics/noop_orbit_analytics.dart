import 'orbit_analytics.dart';

class NoopOrbitAnalytics implements OrbitAnalytics {
  const NoopOrbitAnalytics();

  @override
  Future<void> track({
    required String event,
    required String sessionId,
    required Map<String, Object?> properties,
  }) async {}
}
