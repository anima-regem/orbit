class OrbitInstalledApp {
  const OrbitInstalledApp({
    required this.packageName,
    required this.label,
    required this.isWorkProfile,
  });

  final String packageName;
  final String label;
  final bool isWorkProfile;

  factory OrbitInstalledApp.fromMap(Map<dynamic, dynamic> raw) {
    return OrbitInstalledApp(
      packageName: (raw['packageName']?.toString() ?? '').trim(),
      label: (raw['label']?.toString() ?? '').trim(),
      isWorkProfile: raw['isWorkProfile'] == true,
    );
  }
}
