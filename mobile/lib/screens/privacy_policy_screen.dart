import 'package:beebeebike/app.dart';
import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/screens/legal_document_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
