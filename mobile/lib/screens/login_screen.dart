import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/widgets/login_form.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, this.onSuccess});

  final VoidCallback? onSuccess;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: LoginForm(
          onSuccess: () {
            Navigator.of(context).pop();
            onSuccess?.call();
          },
        ),
      ),
    );
  }
}
