import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import 'login_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final home = ref.watch(homeLocationProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: Text(user?.email ?? 'Guest'),
            subtitle: Text(user?.accountType ?? 'Loading...'),
          ),
          if (home != null)
            ListTile(
              title: const Text('Home'),
              subtitle: Text(home.label),
            ),
          if (user?.email != null)
            ListTile(
              title: const Text('Log out'),
              onTap: () =>
                  ref.read(authControllerProvider.notifier).logout(),
            )
          else
            ListTile(
              title: const Text('Log in'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
            ),
        ],
      ),
    );
  }
}
