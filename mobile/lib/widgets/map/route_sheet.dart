import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/route_preview.dart';
import '../../models/route_state.dart';
import '../../providers/route_provider.dart';
import '../../theme/tokens.dart';
import '../brush_fab.dart';
import '../route_summary.dart';
import 'compass_fab_inline.dart';
import 'recenter_circle_fab.dart';

/// Slides up over the home sheet when a route is active (loading, error, or
/// preview ready). Fixed height; not draggable.
class RouteSheet extends ConsumerWidget {
  const RouteSheet({
    super.key,
    required this.routeState,
    required this.preview,
    required this.onFlyToMyLocation,
    required this.onResetBearing,
    required this.onStart,
  });

  final RouteState routeState;
  final RoutePreview? preview;
  final VoidCallback onFlyToMyLocation;
  final VoidCallback onResetBearing;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CompassFabInline(onResetBearing: onResetBearing),
                RecenterCircleFab(onTap: onFlyToMyLocation),
                const SizedBox(height: 12),
                const BrushFab(),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            decoration: const BoxDecoration(
              color: BbbColors.panel,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(BbbRadius.sheetTop)),
              boxShadow: BbbShadow.panel,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (routeState.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (routeState.error != null)
                    Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(l10n.routeLoadError,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => ref
                              .read(routeControllerProvider.notifier)
                              .clear(),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    )
                  else if (preview != null)
                    RouteSummary(
                      durationMinutes: (preview!.time / 60000).round(),
                      distanceKm: preview!.distance / 1000,
                      onStart: onStart,
                      onClose: () {
                        ref.read(routeControllerProvider.notifier).clear();
                        onFlyToMyLocation();
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
