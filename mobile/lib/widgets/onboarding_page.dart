import 'package:beebeebike/theme/tokens.dart';
import 'package:beebeebike/theme/typography.dart';
import 'package:flutter/material.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    required this.icon, required this.eyebrow, required this.headline, super.key,
    this.body,
    this.bullets,
    this.footer,
    this.actions,
  });

  final IconData icon;
  final String eyebrow;
  final String headline;
  final String? body;
  final List<String>? bullets;
  final Widget? footer;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final bullets = this.bullets;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: BbbColors.brandSoft,
                  borderRadius: BorderRadius.circular(BbbRadius.panel),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 34, color: BbbColors.brand),
              ),
              const SizedBox(height: 24),
              Text(eyebrow.toUpperCase(), style: BbbText.eyebrow()),
              const SizedBox(height: 10),
              Text(
                headline,
                style: BbbText.screenTitle().copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              if (body != null)
                Text(
                  body!,
                  style: BbbText.body().copyWith(
                    color: BbbColors.inkMuted,
                    height: 1.5,
                  ),
                ),
              if (bullets != null) ...[
                const SizedBox(height: 4),
                for (final line in bullets)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8, right: 12),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: BbbColors.brand,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            line,
                            style: BbbText.body().copyWith(
                              fontSize: 14,
                              color: BbbColors.inkMuted,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              if (footer != null) ...[
                const SizedBox(height: 20),
                footer!,
              ],
              if (actions != null) ...[
                const SizedBox(height: 28),
                actions!,
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
