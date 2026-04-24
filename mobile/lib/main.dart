import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'api/client.dart';
import 'config/app_config.dart';
import 'providers/search_history_provider.dart';

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
      options.dsn = config.glitchtipDsn;
      options.environment = config.environment;
      options.tracesSampleRate = 0.0;
      options.attachStacktrace = true;
      // GlitchTip does not support session replay / profiling; keep off.
    },
    appRunner: bootstrap,
  );
}
