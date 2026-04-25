import 'package:fake_async/fake_async.dart';
import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' hide UserLocation;
import 'package:beebeebike/dev/playback_engine.dart';
import 'package:beebeebike/dev/polyline_walker.dart';

void main() {
  // East-running 333 m polyline along the equator.
  final points = [
    const LatLng(0.0, 0.0),
    const LatLng(0.0, 0.001),
    const LatLng(0.0, 0.003),
  ];

  PolylineWalker walker() => PolylineWalker(points);

  group('PlaybackEngine', () {
    test('idle engine emits nothing', () {
      fakeAsync((async) {
        final e = PlaybackEngine();
        final got = <UserLocation>[];
        final sub = e.stream.listen(got.add);
        async.elapse(const Duration(seconds: 1));
        expect(got, isEmpty);
        sub.cancel();
        e.dispose();
      });
    });

    test('play advances cumulative by baseSpeed * multiplier * dt', () {
      fakeAsync((async) {
        final e = PlaybackEngine()
          ..setRoute(walker: walker(), routeBaseSpeedMps: 10.0);
        final got = <UserLocation>[];
        final sub = e.stream.listen(got.add);
        e.play();
        async.elapse(const Duration(seconds: 1)); // 4 ticks
        expect(got, isNotEmpty);
        expect(got.last.lng, closeTo(9.0e-5, 1e-5));
        expect(got.last.speedMps, closeTo(10.0, 1e-9));
        expect(e.state.cumulativeM, closeTo(10.0, 0.01));
        sub.cancel();
        e.dispose();
      });
    });

    test('pause halts advance', () {
      fakeAsync((async) {
        final e = PlaybackEngine()
          ..setRoute(walker: walker(), routeBaseSpeedMps: 10.0);
        e.play();
        async.elapse(const Duration(seconds: 1));
        final atPause = e.state.cumulativeM;
        e.pause();
        async.elapse(const Duration(seconds: 1));
        expect(e.state.cumulativeM, closeTo(atPause, 1e-9));
        e.dispose();
      });
    });

    test('pause emits last position once with speed=0', () {
      fakeAsync((async) {
        final e = PlaybackEngine()
          ..setRoute(walker: walker(), routeBaseSpeedMps: 10.0);
        final got = <UserLocation>[];
        final sub = e.stream.listen(got.add);
        e.play();
        async.elapse(const Duration(seconds: 1));
        final beforePause = got.length;
        e.pause();
        async.flushMicrotasks();
        expect(got.length, greaterThan(beforePause));
        expect(got.last.speedMps, 0.0);
        sub.cancel();
        e.dispose();
      });
    });

    test('override emits override latlng with speed=0; advance halts', () {
      fakeAsync((async) {
        final e = PlaybackEngine()
          ..setRoute(walker: walker(), routeBaseSpeedMps: 10.0);
        final got = <UserLocation>[];
        final sub = e.stream.listen(got.add);
        e.play();
        async.elapse(const Duration(milliseconds: 500));
        e.setOverridePosition(const LatLng(1.234, 5.678));
        async.elapse(const Duration(seconds: 1));
        expect(got.last.lat, closeTo(1.234, 1e-9));
        expect(got.last.lng, closeTo(5.678, 1e-9));
        expect(got.last.speedMps, 0.0);
        sub.cancel();
        e.dispose();
      });
    });

    test('clearOverride snaps back to polyline at cumulative', () {
      fakeAsync((async) {
        final e = PlaybackEngine()
          ..setRoute(walker: walker(), routeBaseSpeedMps: 10.0);
        e.play();
        async.elapse(const Duration(seconds: 1));
        final beforeOverrideCum = e.state.cumulativeM;
        e.setOverridePosition(const LatLng(1.0, 1.0));
        async.elapse(const Duration(milliseconds: 500));
        expect(e.state.cumulativeM, closeTo(beforeOverrideCum, 1e-9));
        e.clearOverride();
        async.elapse(const Duration(milliseconds: 250));
        expect(e.state.overrideLatLng, isNull);
        // Cumulative should now be advancing again.
        final afterClearCum = e.state.cumulativeM;
        async.elapse(const Duration(milliseconds: 250));
        expect(e.state.cumulativeM, greaterThan(afterClearCum));
        e.dispose();
      });
    });

    test('reaching end pauses and clamps cumulative', () {
      fakeAsync((async) {
        final e = PlaybackEngine()
          ..setRoute(walker: walker(), routeBaseSpeedMps: 10.0);
        e.play();
        async.elapse(const Duration(seconds: 60));
        expect(e.state.isPlaying, isFalse);
        expect(e.state.cumulativeM, closeTo(e.state.routeLengthM, 0.01));
        e.dispose();
      });
    });

    test('seek sets cumulative and clamps', () {
      final e = PlaybackEngine()
        ..setRoute(walker: walker(), routeBaseSpeedMps: 10.0);
      e.seek(50.0);
      expect(e.state.cumulativeM, 50.0);
      e.seek(-10);
      expect(e.state.cumulativeM, 0.0);
      e.seek(99999);
      expect(e.state.cumulativeM, e.state.routeLengthM);
      e.dispose();
    });

    test('setSpeedMultiplier updates state', () {
      final e = PlaybackEngine()
        ..setRoute(walker: walker(), routeBaseSpeedMps: 10.0);
      e.setSpeedMultiplier(5.0);
      expect(e.state.speedMultiplier, 5.0);
      e.dispose();
    });

    test('setRoute resets cumulative and stops playback', () {
      final e = PlaybackEngine()
        ..setRoute(walker: walker(), routeBaseSpeedMps: 10.0);
      e.play();
      e.seek(100);
      e.setRoute(walker: walker(), routeBaseSpeedMps: 5.0);
      expect(e.state.cumulativeM, 0.0);
      expect(e.state.isPlaying, isFalse);
      expect(e.state.routeBaseSpeedMps, 5.0);
      e.dispose();
    });
  });
}
