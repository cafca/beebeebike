import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/theme/tokens.dart';
import 'package:flutter/material.dart';

/// 52×52 circular FAB for toggling turn-by-turn voice during navigation.
/// Active (voice on): dark ground, bright icon. Inactive: white ground,
/// muted icon — matches the recenter-idle treatment.
class TtsToggleFab extends StatelessWidget {
  const TtsToggleFab({
    required this.enabled, required this.onTap, super.key,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bg = enabled ? BbbColors.ink : Colors.white;
    final fg = enabled ? Colors.white : BbbColors.inkMuted;
    return Material(
      color: bg,
      surfaceTintColor: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: enabled ? l10n.navMuteVoice : l10n.navEnableVoice,
          child: Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: BbbShadow.sm,
            ),
            child: Icon(
              enabled ? Icons.volume_up : Icons.volume_off,
              color: fg,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
