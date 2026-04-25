import 'package:beebeebike/navigation/camera_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NavigationCameraController', () {
    test('starts in awaitingFirstFix with default zoom 17', () {
      final c = NavigationCameraController();
      expect(c.mode, CameraMode.awaitingFirstFix);
      expect(c.followZoom, 17.0);
    });

    test('onNavStart transitions awaitingFirstFix -> following', () {
      final c = NavigationCameraController()..onNavStart();
      expect(c.mode, CameraMode.following);
    });

    test('onNavStart is a no-op if already following', () {
      final c = NavigationCameraController()
        ..onNavStart()
        ..onNavStart();
      expect(c.mode, CameraMode.following);
    });

    test('onTrackingDismissed transitions following -> free', () {
      final c = NavigationCameraController()
        ..onNavStart()
        ..onTrackingDismissed();
      expect(c.mode, CameraMode.free);
    });

    test('onTrackingDismissed transitions awaitingFirstFix -> free', () {
      // User can pan before the first GPS fix lands; we still want the
      // RecenterFab to surface so they can re-lock when ready.
      final c = NavigationCameraController()..onTrackingDismissed();
      expect(c.mode, CameraMode.free);
    });

    test('onTrackingDismissed is a no-op in arrived', () {
      final c = NavigationCameraController()
        ..onArrived()
        ..onTrackingDismissed();
      expect(c.mode, CameraMode.arrived);
    });

    test('onZoomChanged mutates followZoom iff mode == free', () {
      final c = NavigationCameraController()..onZoomChanged(14);
      expect(c.followZoom, 17.0); // awaitingFirstFix: ignored
      c
        ..onNavStart()
        ..onZoomChanged(15.5);
      expect(c.followZoom, 17.0); // following: ignored
      c
        ..onTrackingDismissed()
        ..onZoomChanged(13.2);
      expect(c.followZoom, 13.2); // free: captured
    });

    test('onRecenterTapped transitions free -> following', () {
      final c = NavigationCameraController()
        ..onNavStart()
        ..onTrackingDismissed()
        ..onRecenterTapped();
      expect(c.mode, CameraMode.following);
    });

    test('onRecenterTapped is a no-op in following', () {
      final c = NavigationCameraController()
        ..onNavStart()
        ..onRecenterTapped();
      expect(c.mode, CameraMode.following);
    });

    test('onArrived transitions any state to arrived', () {
      for (final setup in [
        NavigationCameraController.new,
        () => NavigationCameraController()..onNavStart(),
        () => NavigationCameraController()
          ..onNavStart()
          ..onTrackingDismissed(),
      ]) {
        final c = setup()..onArrived();
        expect(c.mode, CameraMode.arrived);
      }
    });

    test('notifies listeners on every successful transition', () {
      final c = NavigationCameraController();
      var notifications = 0;
      c
        ..addListener(() => notifications++)
        ..onNavStart()
        ..onTrackingDismissed()
        ..onZoomChanged(14)
        ..onRecenterTapped()
        ..onArrived();
      expect(notifications, 5);
    });

    test('does not notify on no-op transitions', () {
      final c = NavigationCameraController();
      var notifications = 0;
      c
        ..addListener(() => notifications++)
        // No-ops from awaitingFirstFix (onTrackingDismissed is a real
        // transition in this state, so it is covered below).
        ..onRecenterTapped()
        ..onZoomChanged(14);
      expect(notifications, 0);

      // Real transition: -> following
      c.onNavStart();
      notifications = 0;

      // No-ops from following
      c
        ..onNavStart()
        ..onZoomChanged(14);
      expect(notifications, 0);

      // Real transitions: -> free, -> arrived
      c
        ..onTrackingDismissed()
        ..onArrived();
      notifications = 0;

      // No-ops from arrived
      c
        ..onArrived()
        ..onTrackingDismissed()
        ..onRecenterTapped()
        ..onZoomChanged(14);
      expect(notifications, 0);
    });
  });
}
