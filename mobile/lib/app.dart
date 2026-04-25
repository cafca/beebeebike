import 'package:beebeebike/config/app_config.dart';
import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/providers/auth_provider.dart';
import 'package:beebeebike/providers/locale_provider.dart';
import 'package:beebeebike/providers/onboarding_provider.dart';
import 'package:beebeebike/screens/map_screen.dart';
import 'package:beebeebike/screens/onboarding_screen.dart';
import 'package:beebeebike/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
