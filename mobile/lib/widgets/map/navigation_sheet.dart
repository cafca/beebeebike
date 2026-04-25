import 'package:beebeebike/navigation/camera_controller.dart';
import 'package:beebeebike/providers/navigation_camera_provider.dart';
import 'package:beebeebike/providers/navigation_provider.dart';
import 'package:beebeebike/theme/tokens.dart';
import 'package:beebeebike/widgets/arrived_sheet.dart';
import 'package:beebeebike/widgets/eta_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Slides up over the route sheet during active navigation. Fixed height;
/// not draggable.
class NavigationSheet extends ConsumerWidget {
  const NavigationSheet({
    required this.onClose, super.key,
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
