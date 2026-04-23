import 'package:flutter_test/flutter_test.dart';
import 'package:beebeebike/navigation/camera_controller.dart';

void main() {
  group('NavigationCameraController', () {
    test('starts in awaitingFirstFix with default zoom 17', () {
      final c = NavigationCameraController();
      expect(c.mode, CameraMode.awaitingFirstFix);
      expect(c.followZoom, 17.0);
    });

    test('onFirstFix transitions awaitingFirstFix -> following', () {
      final c = NavigationCameraController();
      c.onFirstFix();
      expect(c.mode, CameraMode.following);
    });

    test('onFirstFix is a no-op if already following', () {
      final c = NavigationCameraController()..onFirstFix();
      c.onFirstFix();
      expect(c.mode, CameraMode.following);
    });

    test('onTrackingDismissed transitions following -> free', () {
      final c = NavigationCameraController()..onFirstFix();
      c.onTrackingDismissed();
      expect(c.mode, CameraMode.free);
    });

    test('onTrackingDismissed transitions awaitingFirstFix -> free', () {
      // User can pan before the first GPS fix lands; we still want the
      // RecenterFab to surface so they can re-lock when ready.
      final c = NavigationCameraController();
      c.onTrackingDismissed();
      expect(c.mode, CameraMode.free);
    });

    test('onTrackingDismissed is a no-op in arrived', () {
      final c = NavigationCameraController()..onArrived();
      c.onTrackingDismissed();
      expect(c.mode, CameraMode.arrived);
    });

    test('onZoomChanged mutates followZoom iff mode == free', () {
      final c = NavigationCameraController();
      c.onZoomChanged(14.0);
      expect(c.followZoom, 17.0); // awaitingFirstFix: ignored
      c.onFirstFix();
      c.onZoomChanged(15.5);
      expect(c.followZoom, 17.0); // following: ignored
      c.onTrackingDismissed();
      c.onZoomChanged(13.2);
      expect(c.followZoom, 13.2); // free: captured
    });

    test('onRecenterTapped transitions free -> following', () {
      final c = NavigationCameraController()
        ..onFirstFix()
        ..onTrackingDismissed();
      c.onRecenterTapped();
      expect(c.mode, CameraMode.following);
    });

    test('onRecenterTapped is a no-op in following', () {
      final c = NavigationCameraController()..onFirstFix();
      c.onRecenterTapped();
      expect(c.mode, CameraMode.following);
    });

    test('onArrived transitions any state to arrived', () {
      for (final setup in [
        () => NavigationCameraController(),
        () => NavigationCameraController()..onFirstFix(),
        () => NavigationCameraController()
          ..onFirstFix()
          ..onTrackingDismissed(),
      ]) {
        final c = setup();
        c.onArrived();
        expect(c.mode, CameraMode.arrived);
      }
    });

    test('notifies listeners on every successful transition', () {
      final c = NavigationCameraController();
      var notifications = 0;
      c.addListener(() => notifications++);
      c.onFirstFix();
      c.onTrackingDismissed();
      c.onZoomChanged(14.0);
      c.onRecenterTapped();
      c.onArrived();
      expect(notifications, 5);
    });

    test('does not notify on no-op transitions', () {
      final c = NavigationCameraController();
      var notifications = 0;
      c.addListener(() => notifications++);

      // No-ops from awaitingFirstFix (onTrackingDismissed is a real
      // transition in this state, so it is covered below).
      c.onRecenterTapped();
      c.onZoomChanged(14.0);
      expect(notifications, 0);

      // Real transition: -> following
      c.onFirstFix();
      notifications = 0;

      // No-ops from following
      c.onFirstFix();
      c.onZoomChanged(14.0);
      expect(notifications, 0);

      // Real transitions: -> free, -> arrived
      c.onTrackingDismissed();
      c.onArrived();
      notifications = 0;

      // No-ops from arrived
      c.onArrived();
      c.onTrackingDismissed();
      c.onRecenterTapped();
      c.onZoomChanged(14.0);
      expect(notifications, 0);
    });
  });
}
