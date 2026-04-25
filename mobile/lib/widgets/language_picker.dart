import 'dart:async';

import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/providers/locale_provider.dart';
import 'package:beebeebike/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.watch(localeProvider);
    final controller = ref.read(localeProvider.notifier);

    return RadioGroup<LocalePref>(
      groupValue: current,
      onChanged: (v) {
        if (v != null) unawaited(controller.setPref(v));
      },
      child: Column(
        children: [
          RadioListTile<LocalePref>(
            title: Text(l10n.settingsLanguageSystem, style: BbbText.body()),
            value: LocalePref.system,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          RadioListTile<LocalePref>(
            title: Text(l10n.settingsLanguageEnglish, style: BbbText.body()),
            value: LocalePref.en,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          RadioListTile<LocalePref>(
            title: Text(l10n.settingsLanguageGerman, style: BbbText.body()),
            value: LocalePref.de,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ],
      ),
    );
  }
}
