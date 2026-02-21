abstract class OrbitAnalytics {
  Future<void> track({
    required String event,
    required String sessionId,
    required Map<String, Object?> properties,
  });
}
