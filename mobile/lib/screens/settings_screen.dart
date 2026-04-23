import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/language_picker.dart';
import 'login_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: BbbColors.panel,
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        backgroundColor: BbbColors.panel,
        foregroundColor: BbbColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: const [
          _AccountSection(),
          _SectionDivider(),
          _LanguageSection(),
          _SectionDivider(),
          _DangerSection(),
          _CreditsSection(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label, {this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Text(
        label.toUpperCase(),
        style: BbbText.eyebrow().copyWith(color: color),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Divider(height: 1, thickness: 1, color: BbbColors.divider),
    );
  }
}

class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authControllerProvider).valueOrNull;
    final home = ref.watch(homeLocationProvider).valueOrNull;
    final loggedIn = user?.email != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(l10n.settingsSectionAccount),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.email ?? l10n.settingsGuest,
                style: BbbText.cardTitle(),
              ),
              const SizedBox(height: 2),
              Text(
                user?.accountType ?? l10n.commonLoading,
                style: BbbText.monoSub(),
              ),
            ],
          ),
        ),
        if (home != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.settingsHome, style: BbbText.label()),
                const SizedBox(height: 2),
                Text(home.label, style: BbbText.monoSub()),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: _AuthButton(loggedIn: loggedIn),
        ),
      ],
    );
  }
}

class _AuthButton extends ConsumerWidget {
  const _AuthButton({required this.loggedIn});

  final bool loggedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final label = loggedIn ? l10n.settingsLogOut : l10n.settingsLogIn;
    final bg = loggedIn ? BbbColors.bgAlt : BbbColors.ink;
    final fg = loggedIn ? BbbColors.ink : Colors.white;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(BbbRadius.ctrl),
      child: InkWell(
        borderRadius: BorderRadius.circular(BbbRadius.ctrl),
        onTap: () {
          if (loggedIn) {
            ref.read(authControllerProvider.notifier).logout();
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(label, style: BbbText.cardTitle().copyWith(color: fg)),
          ),
        ),
      ),
    );
  }
}

class _LanguageSection extends StatelessWidget {
  const _LanguageSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(l10n.settingsSectionLanguage),
        const LanguagePicker(),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _DangerSection extends ConsumerWidget {
  const _DangerSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authControllerProvider).valueOrNull;
    final isRegistered = user?.accountType == 'registered';
    if (!isRegistered) return const SizedBox.shrink();

    final danger = BbbColors.rampHate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(l10n.settingsSectionDanger, color: danger),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Material(
            color: BbbColors.panel,
            borderRadius: BorderRadius.circular(BbbRadius.ctrl),
            child: InkWell(
              borderRadius: BorderRadius.circular(BbbRadius.ctrl),
              onTap: () => _confirmDelete(context, ref),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: BbbColors.divider),
                  borderRadius: BorderRadius.circular(BbbRadius.ctrl),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.delete_forever_outlined, color: danger),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.settingsDeleteAccount,
                            style: BbbText.label().copyWith(color: danger),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.settingsDeleteAccountSubtitle,
                            style: BbbText.monoSub(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const _SectionDivider(),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final danger = BbbColors.rampHate;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsDeleteConfirmTitle),
        content: Text(l10n.settingsDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.settingsDeleteCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settingsDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsDeleteSuccess)),
      );
      if (navigator.canPop()) navigator.pop();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.settingsDeleteError(error.toString())),
        ),
      );
    }
  }
}

class _CreditsSection extends StatelessWidget {
  const _CreditsSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(l10n.settingsSectionCredits),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: _CreditsList(),
        ),
      ],
    );
  }
}

class _CreditsList extends StatelessWidget {
  const _CreditsList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CreditLink(
          label: l10n.settingsCreditOsm,
          url: 'https://www.openstreetmap.org/copyright',
        ),
        const SizedBox(height: 8),
        _CreditLink(
          label: l10n.settingsCreditMaplibre,
          url: 'https://maplibre.org/',
        ),
        const SizedBox(height: 8),
        _CreditLink(
          label: l10n.settingsCreditGraphhopper,
          url: 'https://www.graphhopper.com/',
        ),
        const SizedBox(height: 8),
        _CreditLink(
          label: l10n.settingsCreditPhoton,
          url: 'https://photon.komoot.io/',
        ),
      ],
    );
  }
}

class _CreditLink extends StatelessWidget {
  const _CreditLink({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: label,
        style: BbbText.body().copyWith(color: BbbColors.brand),
        recognizer: TapGestureRecognizer()
          ..onTap = () => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ),
      ),
    );
  }
}
