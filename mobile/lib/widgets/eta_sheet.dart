import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../navigation/maneuver_icons.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Navigation Sheet (variant C) — grabber, voice + close top-right, hero
/// remaining-time in JB Mono, divider, mono data strip with remaining
/// distance + arrival clock.
class EtaSheet extends StatelessWidget {
  const EtaSheet({
    super.key,
    required this.navState,
    required this.ttsEnabled,
    required this.onToggleTts,
    required this.onClose,
  });

  final AsyncValue<NavigationState> navState;
  final bool ttsEnabled;
  final VoidCallback onToggleTts;
  final VoidCallback onClose;

  String _formatArrival(int durationRemainingMs) {
    final eta = DateTime.now().add(Duration(milliseconds: durationRemainingMs));
    final h = eta.hour.toString().padLeft(2, '0');
    final m = eta.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

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
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: BbbColors.grabber,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: navState.when(
                  loading: () => Text(l10n.commonLoading, style: BbbText.body()),
                  error: (_, __) => Text('—', style: BbbText.body()),
                  data: (state) {
                    final p = state.progress;
                    if (p == null) return Text('—', style: BbbText.body());
                    final mins = (p.durationRemainingMs / 60000).round();
                    return Text('$mins min', style: BbbText.navHero());
                  },
                ),
              ),
              _CircleIconButton(
                icon: ttsEnabled ? Icons.volume_up : Icons.volume_off,
                tooltip: ttsEnabled ? l10n.navMuteVoice : l10n.navEnableVoice,
                onPressed: onToggleTts,
              ),
              const SizedBox(width: 8),
              _CircleIconButton(
                icon: Icons.close,
                tooltip: l10n.navEndNavigation,
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: BbbColors.divider),
          const SizedBox(height: 14),
          navState.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (state) {
              final p = state.progress;
              if (p == null) return const SizedBox.shrink();
              final distText = formatDistance(p.distanceRemainingM);
              final arrival = _formatArrival(p.durationRemainingMs);
              return Row(
                children: [
                  Text(
                    distText,
                    style: BbbText.monoTime(color: BbbColors.ink).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '  ·  ',
                    style: BbbText.monoTime(color: BbbColors.inkFaint),
                  ),
                  Text(
                    'arrives $arrival',
                    style: BbbText.monoTime(color: BbbColors.inkMuted),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, size: 14, color: BbbColors.inkMuted),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: BbbColors.bg,
          minimumSize: const Size(32, 32),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}
