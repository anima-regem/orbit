import 'package:flutter/material.dart';

class OrbitSourceVisuals {
  const OrbitSourceVisuals({
    required this.color,
    required this.icon,
    required this.name,
  });

  final Color color;
  final IconData icon;
  final String name;
}

OrbitSourceVisuals sourceVisualsForPackage(
  String packageName,
  String? fallbackName,
) {
  final String normalized = packageName.toLowerCase();
  switch (normalized) {
    case 'com.spotify.music':
      return const OrbitSourceVisuals(
        color: Color(0xFF1DB954),
        icon: Icons.music_note_rounded,
        name: 'Spotify',
      );
    case 'com.instagram.android':
      return const OrbitSourceVisuals(
        color: Color(0xFFE95950),
        icon: Icons.camera_alt_rounded,
        name: 'Instagram',
      );
    case 'com.whatsapp':
      return const OrbitSourceVisuals(
        color: Color(0xFF25D366),
        icon: Icons.forum_rounded,
        name: 'WhatsApp',
      );
    case 'com.google.android.gm':
      return const OrbitSourceVisuals(
        color: Color(0xFFDB4437),
        icon: Icons.mail_rounded,
        name: 'Gmail',
      );
    case 'com.slack':
    case 'com.slack.android':
      return const OrbitSourceVisuals(
        color: Color(0xFF4A154B),
        icon: Icons.work_rounded,
        name: 'Slack',
      );
    default:
      return OrbitSourceVisuals(
        color: _colorFromString(normalized),
        icon: Icons.notifications_rounded,
        name: fallbackName ?? normalized,
      );
  }
}

Color _colorFromString(String value) {
  final int hash = value.hashCode & 0x00FFFFFF;
  final int r = 70 + ((hash >> 16) & 0x7F);
  final int g = 70 + ((hash >> 8) & 0x7F);
  final int b = 70 + (hash & 0x7F);
  return Color.fromARGB(255, r, g, b);
}
