import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../navigation/maneuver_icons.dart';
import '../providers/route_provider.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Distance (m) within which, if the destination has a house number,
/// the ETA hero swaps from "$mins min" to the street + house number so
/// the rider sees exactly where to stop.
const double _arrivalAddressThresholdM = 200;

/// Navigation Sheet (variant C) — close top-right, hero remaining-time
/// in JB Mono (or street+housenumber when close to destination), divider,
/// mono data strip with remaining distance + arrival clock.
class EtaSheet extends ConsumerWidget {
  const EtaSheet({
    super.key,
    required this.navState,
    required this.onClose,
  });

  final AsyncValue<NavigationState> navState;
  final VoidCallback onClose;

  String _formatArrival(int durationRemainingMs) {
    final eta = DateTime.now().add(Duration(milliseconds: durationRemainingMs));
    final h = eta.hour.toString().padLeft(2, '0');
    final m = eta.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final destination = ref.watch(routeControllerProvider).destination;
    final addressLabel = (destination?.housenumber != null &&
            destination?.street != null)
        ? '${destination!.street} ${destination.housenumber}'
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                    final heroStyle =
                        BbbText.navHero(color: BbbColors.inkMuted);
                    if (addressLabel != null &&
                        p.distanceRemainingM < _arrivalAddressThresholdM) {
                      return Text(
                        addressLabel,
                        style: heroStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    }
                    final mins = (p.durationRemainingMs / 60000).round();
                    return Text('$mins min', style: heroStyle);
                  },
                ),
              ),
              _CircleIconButton(
                icon: Icons.close,
                tooltip: l10n.navEndNavigation,
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: BbbColors.divider),
          const SizedBox(height: 6),
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
                    style: BbbText.monoTime(color: BbbColors.inkMuted).copyWith(
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
