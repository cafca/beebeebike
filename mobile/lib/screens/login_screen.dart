import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/auth_provider.dart';

enum _LoginErrorKind { invalidCredentials }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('login_email'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l10n.loginEmail),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.loginErrorEmptyEmail
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('login_password'),
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.loginPassword),
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
      ),
    );
  }
}
