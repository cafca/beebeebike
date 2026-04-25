import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/theme/tokens.dart';
import 'package:beebeebike/theme/typography.dart';
import 'package:flutter/material.dart';

class ReroutingToast extends StatelessWidget {
  const ReroutingToast({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: BbbColors.ink,
        borderRadius: BorderRadius.circular(BbbRadius.chip),
        boxShadow: BbbShadow.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            l10n.navRerouting,
            style: BbbText.monoTime(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
