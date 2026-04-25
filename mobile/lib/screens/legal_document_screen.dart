import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/tokens.dart';

class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
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
            if (!(error.isForMainFrame ?? true)) return;
            setState(() {
              _loading = false;
              _error = error.description;
            });
          },
        ),
      )
      ..loadRequest(_embedUri(widget.url));
  }

  Uri _embedUri(String url) {
    final uri = Uri.parse(url);
    final params = Map<String, String>.from(uri.queryParameters);
    params['embed'] = '1';
    return uri.replace(queryParameters: params);
  }

  Future<void> _openExternally() async {
    await launchUrl(
      Uri.parse(widget.url),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: BbbColors.bg,
      appBar: AppBar(title: Text(widget.title)),
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
