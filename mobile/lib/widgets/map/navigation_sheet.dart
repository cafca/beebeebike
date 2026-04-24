import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../navigation/camera_controller.dart';
import '../../providers/navigation_camera_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../theme/tokens.dart';
import '../arrived_sheet.dart';
import '../eta_sheet.dart';

/// Slides up over the route sheet during active navigation. Fixed height;
/// not draggable.
class NavigationSheet extends ConsumerWidget {
  const NavigationSheet({
    super.key,
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(navigationStateProvider);
    final cam = ref.watch(navigationCameraControllerProvider);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: BbbColors.panel,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(BbbRadius.sheetTop)),
          boxShadow: BbbShadow.panel,
        ),
        child: SafeArea(
          top: false,
          child: cam.mode == CameraMode.arrived
              ? ArrivedSheet(onDone: onClose)
              : EtaSheet(
                  navState: navState,
                  onClose: onClose,
                ),
        ),
      ),
    );
  }
}
