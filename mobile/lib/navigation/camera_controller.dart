import 'package:flutter/foundation.dart';

enum CameraMode { awaitingFirstFix, following, free, arrived }

class NavigationCameraController extends ChangeNotifier {
  CameraMode _mode = CameraMode.awaitingFirstFix;
  double _followZoom = 17.0;

  CameraMode get mode => _mode;
  double get followZoom => _followZoom;

  void onFirstFix() {
    if (_mode != CameraMode.awaitingFirstFix) return;
    _mode = CameraMode.following;
    notifyListeners();
  }

  void onTrackingDismissed() {
    if (_mode != CameraMode.following) return;
    _mode = CameraMode.free;
    notifyListeners();
  }

  void onZoomChanged(double zoom) {
    if (_mode != CameraMode.free) return;
    _followZoom = zoom;
    notifyListeners();
  }

  void onRecenterTapped() {
    if (_mode != CameraMode.free) return;
    _mode = CameraMode.following;
    notifyListeners();
  }

  void onArrived() {
    if (_mode == CameraMode.arrived) return;
    _mode = CameraMode.arrived;
    notifyListeners();
  }
}
