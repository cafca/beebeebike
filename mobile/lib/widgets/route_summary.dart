import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                l10n.routeSummary(durationMinutes, distanceKm.toStringAsFixed(1)),
              ),
            ),
            if (onClose != null)
              IconButton(
                tooltip: l10n.routeClearTooltip,
                icon: const Icon(Icons.close),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: onStart,
          child: Text(l10n.routeStart),
        ),
      ],
    );
  }
}
