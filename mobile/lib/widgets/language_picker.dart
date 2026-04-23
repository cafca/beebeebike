import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/locale_provider.dart';

class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.watch(localeProvider);
    final controller = ref.read(localeProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            l10n.settingsLanguage,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        RadioGroup<LocalePref>(
          groupValue: current,
          onChanged: (v) {
            if (v != null) controller.setPref(v);
          },
          child: Column(
            children: [
              RadioListTile<LocalePref>(
                title: Text(l10n.settingsLanguageSystem),
                value: LocalePref.system,
              ),
              RadioListTile<LocalePref>(
                title: Text(l10n.settingsLanguageEnglish),
                value: LocalePref.en,
              ),
              RadioListTile<LocalePref>(
                title: Text(l10n.settingsLanguageGerman),
                value: LocalePref.de,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
