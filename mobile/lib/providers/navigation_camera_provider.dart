import 'package:beebeebike/navigation/camera_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final AutoDisposeChangeNotifierProvider<NavigationCameraController> navigationCameraControllerProvider =
    ChangeNotifierProvider.autoDispose<NavigationCameraController>((ref) {
  final controller = NavigationCameraController();
  return controller;
});
