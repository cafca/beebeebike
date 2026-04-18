import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/camera_controller.dart';

final navigationCameraControllerProvider =
    Provider.autoDispose<NavigationCameraController>((ref) {
  final controller = NavigationCameraController();
  ref.onDispose(controller.dispose);
  return controller;
});
