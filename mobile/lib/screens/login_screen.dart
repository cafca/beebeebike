import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../widgets/login_form.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: LoginForm(
          onSuccess: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
