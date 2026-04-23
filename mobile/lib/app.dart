import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_config.dart';
import 'l10n/generated/app_localizations.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/onboarding_provider.dart';
import 'screens/map_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());

class BeeBeeBikeApp extends ConsumerWidget {
  const BeeBeeBikeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localePref = ref.watch(localeProvider);

    return MaterialApp(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx)!.appTitle,
      locale: localePref.materialLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildBbbTheme(),
      home: const _RootGate(),
    );
  }
}

class _RootGate extends ConsumerWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingDone = ref.watch(onboardingCompletedProvider);
    if (!onboardingDone) {
      return const OnboardingScreen();
    }
    // Anonymous session + home location fetch happen here — only after the
    // user has seen the data-processing disclosure on the onboarding flow.
    ref.watch(authControllerProvider);
    return const MapScreen();
  }
}
