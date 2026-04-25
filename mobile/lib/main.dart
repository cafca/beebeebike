import 'dart:async';

import 'package:beebeebike/api/client.dart';
import 'package:beebeebike/app.dart';
import 'package:beebeebike/config/app_config.dart';
import 'package:beebeebike/providers/search_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  final config = AppConfig.fromEnvironment();

  Future<void> bootstrap() async {
    WidgetsFlutterBinding.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    final supportDir = await getApplicationSupportDirectory();
    runApp(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          sharedPreferencesProvider.overrideWithValue(prefs),
          cookieStoragePathProvider.overrideWithValue(supportDir.path),
        ],
        child: const BeeBeeBikeApp(),
      ),
    );
  }

  if (config.glitchtipDsn.isEmpty) {
    await bootstrap();
    return;
  }

  await SentryFlutter.init(
    (options) {
      options
        ..dsn = config.glitchtipDsn
        ..environment = config.environment
        ..tracesSampleRate = 0.0
        ..attachStacktrace = true;
      // GlitchTip does not support session replay / profiling; keep off.
    },
    appRunner: bootstrap,
  );
}
