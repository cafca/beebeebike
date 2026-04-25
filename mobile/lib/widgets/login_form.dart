import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _LoginErrorKind { invalidCredentials }

class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key, this.onSuccess});

  final VoidCallback? onSuccess;

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  _LoginErrorKind? _errorKind;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _errorKind = null;
    });

    TextInput.finishAutofillContext();

    await ref.read(authControllerProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        );

    if (!mounted) return;

    final result = ref.read(authControllerProvider);
    if (result is AsyncError) {
      setState(() {
        _errorKind = _LoginErrorKind.invalidCredentials;
        _loading = false;
      });
    } else {
      widget.onSuccess?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('login_email'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.loginEmail,
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.loginErrorEmptyEmail
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('login_password'),
              controller: _passwordController,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.loginPassword,
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (v) => (v == null || v.isEmpty)
                  ? l10n.loginErrorEmptyPassword
                  : null,
            ),
            const SizedBox(height: 8),
            if (_errorKind != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l10n.loginErrorInvalid,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('login_submit'),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.loginSubmit),
            ),
          ],
        ),
      ),
    );
  }
}
