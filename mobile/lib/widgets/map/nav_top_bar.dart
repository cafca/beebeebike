import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/navigation/camera_controller.dart';
import 'package:beebeebike/navigation/maneuver_icons.dart';
import 'package:beebeebike/navigation/nav_constants.dart';
import 'package:beebeebike/providers/navigation_camera_provider.dart';
import 'package:beebeebike/providers/navigation_provider.dart';
import 'package:beebeebike/widgets/map/compass_fab_inline.dart';
import 'package:beebeebike/widgets/recenter_fab.dart';
import 'package:beebeebike/widgets/rerouting_toast.dart';
import 'package:beebeebike/widgets/tts_toggle_fab.dart';
import 'package:beebeebike/widgets/turn_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// TurnBanner + RecenterFab, shown during navigation above the navigation
/// sheet.
class NavTopBar extends ConsumerWidget {
  const NavTopBar({
    required this.ttsEnabled, required this.rerouting, required this.onToggleTts, required this.onRecenter, required this.onResetBearing, super.key,
  });

  final bool ttsEnabled;
  final bool rerouting;
  final VoidCallback onToggleTts;
  final VoidCallback onRecenter;
  final VoidCallback onResetBearing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final navState = ref.watch(navigationStateProvider);
    final cam = ref.watch(navigationCameraControllerProvider);

    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                navState.when(
                  loading: () => TurnBanner(
                    primaryText: l10n.navStarting,
                    distanceText: '',
                  ),
                  error: (e, _) => TurnBanner(
                    primaryText: l10n.navError,
                    distanceText: '',
                    icon: Icons.error_outline,
                  ),
                  data: (state) => TurnBanner(
                    primaryText:
                        state.currentVisual?.primaryText ?? l10n.navOnRoute,
                    distanceText: state.progress != null
                        ? formatDistance(
                            state.progress!.distanceToNextManeuverM)
                        : '',
                    icon: state.currentVisual != null
                        ? iconForManeuver(
                            state.currentVisual!.maneuverType,
                            state.currentVisual!.maneuverModifier,
                          )
                        : Icons.straight,
                  ),
                ),
                if (rerouting) const ReroutingToast(),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.only(right: 16, bottom: kEtaSheetHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TtsToggleFab(enabled: ttsEnabled, onTap: onToggleTts),
                  if (cam.mode == CameraMode.free) ...[
                    const SizedBox(height: 12),
                    CompassFabInline(onResetBearing: onResetBearing),
                    RecenterFab(onTap: onRecenter),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
