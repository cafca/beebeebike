import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../widgets/language_picker.dart';
import 'login_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authControllerProvider).valueOrNull;
    final home = ref.watch(homeLocationProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          ListTile(
            title: Text(user?.email ?? l10n.settingsGuest),
            subtitle: Text(user?.accountType ?? l10n.commonLoading),
          ),
          if (home != null)
            ListTile(
              title: Text(l10n.settingsHome),
              subtitle: Text(home.label),
            ),
          if (user?.email != null)
            ListTile(
              title: Text(l10n.settingsLogOut),
              onTap: () =>
                  ref.read(authControllerProvider.notifier).logout(),
            )
          else
            ListTile(
              title: Text(l10n.settingsLogIn),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
            ),
          const Divider(),
          const LanguagePicker(),
        ],
      ),
    );
  }
}
