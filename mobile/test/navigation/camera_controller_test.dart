import 'package:flutter_test/flutter_test.dart';
import 'package:beebeebike/navigation/camera_controller.dart';

void main() {
  test('disables follow mode when user pans', () {
    final controller = NavigationCameraController();
    expect(controller.followMode, isTrue);

    controller.onUserPan();
    expect(controller.followMode, isFalse);

    controller.recenter();
    expect(controller.followMode, isTrue);
  });
}
