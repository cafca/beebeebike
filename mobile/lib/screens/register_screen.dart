import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/widgets/register_form.dart';
import 'package:flutter/material.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key, this.onSuccess});

  final VoidCallback? onSuccess;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.registerTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: RegisterForm(
          onSuccess: () {
            Navigator.of(context).pop();
            onSuccess?.call();
          },
        ),
      ),
    );
  }
}
