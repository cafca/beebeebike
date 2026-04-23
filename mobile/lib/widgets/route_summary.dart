import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Route Sheet (variant B) body — mono data strip + Start ride / heart row.
/// The heart is visually present but disabled in this build.
class RouteSummary extends StatelessWidget {
  const RouteSummary({
    super.key,
    required this.durationMinutes,
    required this.distanceKm,
    required this.onStart,
    this.onClose,
  });

  final int durationMinutes;
  final double distanceKm;
  final VoidCallback onStart;
  final VoidCallback? onClose;

  String _formatEta() {
    final eta = DateTime.now().add(Duration(minutes: durationMinutes));
    final h = eta.hour.toString().padLeft(2, '0');
    final m = eta.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final close = onClose;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _DataStrip(
                duration: durationMinutes,
                distanceKm: distanceKm,
                eta: _formatEta(),
              ),
            ),
            if (close != null)
              Tooltip(
                message: l10n.routeClearTooltip,
                child: _CloseButton(onTap: close),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StartRideButton(onTap: onStart),
            ),
            const SizedBox(width: 10),
            const _SaveButton(enabled: false),
          ],
        ),
      ],
    );
  }
}

class _DataStrip extends StatelessWidget {
  const _DataStrip({
    required this.duration,
    required this.distanceKm,
    required this.eta,
  });

  final int duration;
  final double distanceKm;
  final String eta;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mono = BbbText.monoTime();
    final sep = TextSpan(
      text: '  ·  ',
      style: mono.copyWith(color: BbbColors.inkFaint),
    );
    return Text.rich(
      TextSpan(
        style: mono,
        children: [
          TextSpan(text: '$duration min'),
          sep,
          TextSpan(text: '${distanceKm.toStringAsFixed(1)} km'),
          sep,
          TextSpan(text: l10n.routeEta(eta)),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BbbColors.bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 32,
          height: 32,
          child: Icon(Icons.close, size: 14, color: BbbColors.inkMuted),
        ),
      ),
    );
  }
}

class _StartRideButton extends StatelessWidget {
  const _StartRideButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: BbbColors.ink,
      borderRadius: BorderRadius.circular(BbbRadius.ctrl),
      child: InkWell(
        borderRadius: BorderRadius.circular(BbbRadius.ctrl),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          child: Center(
            child: Text(
              l10n.routeStartRide,
              style: BbbText.cardTitle().copyWith(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: BbbColors.panel,
          borderRadius: BorderRadius.circular(BbbRadius.ctrl),
          border: Border.all(color: BbbColors.divider, width: 1),
        ),
        child: const Icon(
          Icons.favorite_border,
          size: 22,
          color: BbbColors.inkMuted,
        ),
      ),
    );
  }
}
