import 'dart:async';

import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/providers/onboarding_provider.dart';
import 'package:beebeebike/screens/login_screen.dart';
import 'package:beebeebike/screens/privacy_policy_screen.dart';
import 'package:beebeebike/screens/register_screen.dart';
import 'package:beebeebike/theme/tokens.dart';
import 'package:beebeebike/theme/typography.dart';
import 'package:beebeebike/widgets/onboarding_dots.dart';
import 'package:beebeebike/widgets/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pageCount = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goNext() {
    unawaited(_controller.nextPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    ));
  }

  void _goBack() {
    unawaited(_controller.previousPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    ));
  }

  Future<void> _complete() async {
    await ref.read(onboardingCompletedProvider.notifier).complete();
  }

  void _openRegister() {
    unawaited(Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RegisterScreen(onSuccess: _complete),
      ),
    ));
  }

  void _openLogin() {
    unawaited(Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(onSuccess: _complete),
      ),
    ));
  }

  void _openPrivacyPolicy() {
    unawaited(Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const PrivacyPolicyScreen()),
    ));
  }

  String _eyebrow(int i) => '0${i + 1} / 0$_pageCount';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: BbbColors.bg,
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (index) => setState(() => _page = index),
              children: [
                OnboardingPage(
                  icon: Icons.brush_outlined,
                  eyebrow: _eyebrow(0),
                  headline: l10n.onboarding1Headline,
                  body: l10n.onboarding1Body,
                ),
                OnboardingPage(
                  icon: Icons.shield_outlined,
                  eyebrow: _eyebrow(1),
                  headline: l10n.onboarding2Headline,
                  bullets: [
                    l10n.onboarding2Bullet1,
                    l10n.onboarding2Bullet2,
                    l10n.onboarding2Bullet3,
                    l10n.onboarding2Bullet4,
                  ],
                  footer: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _openPrivacyPolicy,
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: Text(l10n.onboardingPrivacyLink),
                      style: TextButton.styleFrom(
                        foregroundColor: BbbColors.brand,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 6),
                        textStyle: BbbText.label(),
                      ),
                    ),
                  ),
                ),
                OnboardingPage(
                  icon: Icons.cloud_sync_outlined,
                  eyebrow: _eyebrow(2),
                  headline: l10n.onboarding3Headline,
                  body: l10n.onboarding3Body,
                  actions: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        key: const ValueKey('onboarding-register'),
                        onPressed: _openRegister,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(BbbRadius.ctrl),
                          ),
                        ),
                        child: Text(l10n.onboardingCreateAccount),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        key: const ValueKey('onboarding-login'),
                        onPressed: _openLogin,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BbbColors.ink,
                          side: const BorderSide(color: BbbColors.divider),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(BbbRadius.ctrl),
                          ),
                          textStyle: BbbText.cardTitle(),
                        ),
                        child: Text(l10n.onboardingLogin),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        key: const ValueKey('onboarding-skip'),
                        onPressed: _complete,
                        style: TextButton.styleFrom(
                          foregroundColor: BbbColors.inkMuted,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          textStyle: BbbText.label(),
                        ),
                        child: Text(l10n.onboardingSkip),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: _page == 0
                        ? const SizedBox.shrink()
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _goBack,
                              style: TextButton.styleFrom(
                                foregroundColor: BbbColors.inkMuted,
                                textStyle: BbbText.label(),
                              ),
                              child: Text(l10n.onboardingBack),
                            ),
                          ),
                  ),
                  Expanded(
                    child: Center(
                      child: OnboardingDots(
                          current: _page, total: _pageCount),
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: _page < _pageCount - 1
                        ? Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              key: const ValueKey('onboarding-next'),
                              onPressed: _goNext,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 12),
                              ),
                              child: Text(l10n.onboardingNext),
                            ),
                          )
                        : const SizedBox.shrink(),
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
