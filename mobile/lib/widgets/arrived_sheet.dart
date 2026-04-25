import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/theme/tokens.dart';
import 'package:beebeebike/theme/typography.dart';
import 'package:flutter/material.dart';

class ArrivedSheet extends StatelessWidget {
  const ArrivedSheet({required this.onDone, super.key});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: BbbColors.grabber,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(l10n.arrivedTitle, style: BbbText.navHero()),
          const SizedBox(height: 14),
          Material(
            color: BbbColors.ink,
            borderRadius: BorderRadius.circular(BbbRadius.ctrl),
            child: InkWell(
              borderRadius: BorderRadius.circular(BbbRadius.ctrl),
              onTap: onDone,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    l10n.arrivedDone,
                    style: BbbText.cardTitle().copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
