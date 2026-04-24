import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/auth_provider.dart';

enum _RegisterErrorKind { emailTaken, generic }

class RegisterForm extends ConsumerStatefulWidget {
  const RegisterForm({super.key, this.onSuccess});

  final VoidCallback? onSuccess;

  @override
  ConsumerState<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends ConsumerState<RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  _RegisterErrorKind? _errorKind;

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

    await ref.read(authControllerProvider.notifier).register(
          _emailController.text.trim(),
          _passwordController.text,
          null,
        );

    if (!mounted) return;

    final result = ref.read(authControllerProvider);
    if (result is AsyncError) {
      final error = result.error;
      final taken = error is DioException &&
          error.response?.statusCode == 409;
      setState(() {
        _errorKind = taken
            ? _RegisterErrorKind.emailTaken
            : _RegisterErrorKind.generic;
        _loading = false;
      });
    } else {
      widget.onSuccess?.call();
    }
  }

  String? _errorText(AppLocalizations l10n) {
    switch (_errorKind) {
      case _RegisterErrorKind.emailTaken:
        return l10n.registerErrorEmailTaken;
      case _RegisterErrorKind.generic:
        return l10n.registerErrorGeneric;
      case null:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final errorText = _errorText(l10n);
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('register_email'),
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
              key: const Key('register_password'),
              controller: _passwordController,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.loginPassword,
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return l10n.loginErrorEmptyPassword;
                }
                if (v.length < 8) {
                  return l10n.registerErrorPasswordTooShort;
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            if (errorText != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  errorText,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('register_submit'),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.registerSubmit),
            ),
          ],
        ),
      ),
    );
  }
}
