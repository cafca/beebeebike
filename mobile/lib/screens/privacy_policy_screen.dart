import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/tokens.dart';

const String privacyPolicyUrl = 'https://beebeebike.com/datenschutz/';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(BbbColors.bg)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (error) {
            if (!error.isForMainFrame!) return;
            setState(() {
              _loading = false;
              _error = error.description;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(privacyPolicyUrl));
  }

  Future<void> _openExternally() async {
    await launchUrl(
      Uri.parse(privacyPolicyUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: BbbColors.bg,
      appBar: AppBar(title: Text(l10n.onboardingPrivacyTitle)),
      body: Stack(
        children: [
          if (_error == null) WebViewWidget(controller: _controller),
          if (_loading && _error == null)
            const Center(
              child: CircularProgressIndicator(color: BbbColors.brand),
            ),
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined,
                        size: 48, color: BbbColors.inkFaint),
                    const SizedBox(height: 16),
                    Text(
                      l10n.onboardingPrivacyLoadError,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.open_in_browser),
                      label: Text(l10n.onboardingPrivacyOpenBrowser),
                      onPressed: _openExternally,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
