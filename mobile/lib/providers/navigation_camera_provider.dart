import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/camera_controller.dart';

final navigationCameraControllerProvider =
    ChangeNotifierProvider.autoDispose<NavigationCameraController>((ref) {
  final controller = NavigationCameraController();
  return controller;
});
