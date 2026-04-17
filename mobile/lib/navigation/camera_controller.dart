class NavigationCameraController {
  bool followMode = true;

  void onUserPan() {
    followMode = false;
  }

  void recenter() {
    followMode = true;
  }
}
