import 'package:flutter/material.dart';

import 'features/shell/orbit_shell_scaffold.dart';

class OrbitLiteApp extends StatelessWidget {
  const OrbitLiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E365A),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Orbit Lite',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF2F5FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const OrbitShellScaffold(),
    );
  }
}
