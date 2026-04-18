import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_config.dart';
import 'providers/auth_provider.dart';
import 'screens/map_screen.dart';

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());

class BeeBeeBikeApp extends ConsumerWidget {
  const BeeBeeBikeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly initialise auth so the session cookie is ready before any
    // route/geocode API call. The value is intentionally ignored here.
    ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'BeeBeeBike',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E6F66),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F3EC),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}
