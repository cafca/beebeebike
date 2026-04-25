import 'dart:math' as math;

import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/providers/map_bearing_provider.dart';
import 'package:beebeebike/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Inline compass that sits above a RecenterFab in each sheet. Reads
/// the map bearing from [mapBearingProvider] and renders nothing when
/// the map is ~north-up; otherwise shows a rotated glyph + spacer,
/// tapping animates the map back to bearing 0.
class CompassFabInline extends ConsumerWidget {
  const CompassFabInline({required this.onResetBearing, super.key});

  final VoidCallback onResetBearing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bearing = ref.watch(mapBearingProvider);
    if (bearing.abs() <= 0.5) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Tooltip(
        message: l10n.mapResetNorth,
        child: Material(
          shape: const CircleBorder(),
          color: BbbColors.panel,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onResetBearing,
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: BbbColors.panel,
                shape: BoxShape.circle,
                boxShadow: BbbShadow.sm,
              ),
              child: Transform.rotate(
                angle: -bearing * math.pi / 180,
                child: const Icon(
                  Icons.navigation,
                  size: 22,
                  color: BbbColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
