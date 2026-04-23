import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'map_attribution.dart';

/// Route Sheet (variant B) body — mono data strip + Start ride / heart row.
class RouteSummary extends StatefulWidget {
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

  @override
  State<RouteSummary> createState() => _RouteSummaryState();
}

class _RouteSummaryState extends State<RouteSummary> {
  bool _saved = false;

  String _formatEta() {
    final eta = DateTime.now().add(Duration(minutes: widget.durationMinutes));
    final h = eta.hour.toString().padLeft(2, '0');
    final m = eta.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final onClose = widget.onClose;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _DataStrip(
                duration: widget.durationMinutes,
                distanceKm: widget.distanceKm,
                eta: _formatEta(),
              ),
            ),
            if (onClose != null)
              Tooltip(
                message: l10n.routeClearTooltip,
                child: _CloseButton(onTap: onClose),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StartRideButton(onTap: widget.onStart),
            ),
            const SizedBox(width: 10),
            _SaveButton(
              saved: _saved,
              onTap: () => setState(() => _saved = !_saved),
            ),
          ],
        ),
        const MapAttribution(),
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
          TextSpan(text: 'ETA $eta'),
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
              'Start ride',
              style: BbbText.cardTitle().copyWith(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saved, required this.onTap});

  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BbbColors.panel,
      borderRadius: BorderRadius.circular(BbbRadius.ctrl),
      child: InkWell(
        borderRadius: BorderRadius.circular(BbbRadius.ctrl),
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BbbRadius.ctrl),
            border: Border.all(color: BbbColors.divider, width: 1),
          ),
          child: Icon(
            saved ? Icons.favorite : Icons.favorite_border,
            size: 22,
            color: saved ? BbbColors.brand : BbbColors.inkMuted,
          ),
        ),
      ),
    );
  }
}
