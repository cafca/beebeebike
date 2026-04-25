import 'package:flutter/foundation.dart';

enum CameraMode { awaitingFirstFix, following, free, arrived }

class NavigationCameraController extends ChangeNotifier {
  CameraMode _mode = CameraMode.awaitingFirstFix;
  double _followZoom = 17;

  CameraMode get mode => _mode;
  double get followZoom => _followZoom;

  /// Transitions awaitingFirstFix → following. Called when nav starts and we
  /// already have a cached user location, or (edge case) when the first
  /// location update arrives during nav after the session began with no fix.
  void onNavStart() {
    if (_mode != CameraMode.awaitingFirstFix) return;
    _mode = CameraMode.following;
    notifyListeners();
  }

  void onTrackingDismissed() {
    // Accept dismissals from both following (user pans during active nav)
    // and awaitingFirstFix (user pans before first GPS fix lands), so the
    // RecenterFab surfaces in either case. Bailing in arrived keeps the
    // post-arrival camera flight from flipping us back to free.
    if (_mode != CameraMode.following &&
        _mode != CameraMode.awaitingFirstFix) {
      return;
    }
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
