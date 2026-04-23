import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'api/client.dart';
import 'config/app_config.dart';
import 'providers/search_history_provider.dart';

void main() async {
  const dsn = String.fromEnvironment('BEEBEEBIKE_GLITCHTIP_DSN');

  Future<void> appRunner() async {
    WidgetsFlutterBinding.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    final supportDir = await getApplicationSupportDirectory();
    runApp(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(AppConfig.fromEnvironment()),
          sharedPreferencesProvider.overrideWithValue(prefs),
          cookieStoragePathProvider.overrideWithValue(supportDir.path),
        ],
        child: const BeeBeeBikeApp(),
      ),
    );
  }

  if (dsn.isEmpty) {
    await appRunner();
  } else {
    await SentryFlutter.init(
      (options) {
        options.dsn = dsn;
        options.tracesSampleRate = 0.2;
      },
      appRunner: appRunner,
    );
  }
}
