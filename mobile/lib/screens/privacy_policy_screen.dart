import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../l10n/generated/app_localizations.dart';
import 'legal_document_screen.dart';

class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return LegalDocumentScreen(
      title: l10n.onboardingPrivacyTitle,
      url: ref.read(appConfigProvider).privacyPolicyUrl,
    );
  }
}
