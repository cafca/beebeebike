import 'dart:async';

import 'package:beebeebike/dev/playback_constants.dart';
import 'package:beebeebike/dev/playback_state.dart';
import 'package:beebeebike/dev/polyline_walker.dart';
import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:maplibre_gl/maplibre_gl.dart' hide UserLocation;

class PlaybackEngine {
  PlaybackEngine();

  final _controller = StreamController<UserLocation>.broadcast();
  Timer? _timer;
  PolylineWalker? _walker;
  PlaybackState _state = const PlaybackState();
  double _lastBearing = 0;

  Stream<UserLocation> get stream => _controller.stream;
  PlaybackState get state => _state;

  void setRoute({
    required PolylineWalker walker,
    required double routeBaseSpeedMps,
  }) {
    _walker = walker;
    _state = _state.copyWith(
      routeLengthM: walker.totalLengthM,
      routeBaseSpeedMps: routeBaseSpeedMps,
      cumulativeM: 0,
      isPlaying: false,
      overrideLatLng: null,
    );
    _stopTimer();
  }

  void clearRoute() {
    _walker = null;
    _state = const PlaybackState();
    _stopTimer();
  }

  void play() {
    if (_walker == null) return;
    if (_state.isPlaying) return;
    _state = _state.copyWith(isPlaying: true);
    _startTimer();
  }

  void pause() {
    _state = _state.copyWith(isPlaying: false);
    _emitCurrent();
    _stopTimer();
  }

  void seek(double cumulativeM) {
    final clamped = cumulativeM.clamp(0.0, _state.routeLengthM);
    _state = _state.copyWith(cumulativeM: clamped);
    _emitCurrent();
  }

  void step(double meters) => seek(_state.cumulativeM + meters);

  void setSpeedMultiplier(double m) {
    _state = _state.copyWith(speedMultiplier: m);
  }

  void setOverridePosition(LatLng latLng) {
    if (_walker == null) return;
    _state = _state.copyWith(overrideLatLng: latLng);
    if (_timer == null) _startTimer();
    _emitCurrent();
  }

  void clearOverride() {
    _state = _state.copyWith(overrideLatLng: null);
    if (!_state.isPlaying) _stopTimer();
    _emitCurrent();
  }

  void dispose() {
    _stopTimer();
    unawaited(_controller.close());
  }

  void _startTimer() {
    _timer ??= Timer.periodic(kPlaybackTickInterval, _onTick);
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _onTick(Timer _) {
    final walker = _walker;
    if (walker == null) return;
    if (_state.overrideLatLng != null) {
      _emitCurrent();
      return;
    }
    if (!_state.isPlaying) {
      _emitCurrent();
      _stopTimer();
      return;
    }
    const dt = 1.0 / kPlaybackTickHz;
    final advance = _state.routeBaseSpeedMps * _state.speedMultiplier * dt;
    final next = (_state.cumulativeM + advance).clamp(0.0, _state.routeLengthM);
    final reachedEnd = next >= _state.routeLengthM;
    _state = _state.copyWith(
      cumulativeM: next,
      isPlaying: !reachedEnd,
    );
    if (reachedEnd) _stopTimer();
    _emitCurrent();
  }

  void _emitCurrent() {
    final walker = _walker;
    if (walker == null) return;
    final override = _state.overrideLatLng;
    if (override != null) {
      _controller.add(UserLocation(
        lat: override.latitude,
        lng: override.longitude,
        horizontalAccuracyM: kPlaybackFakeAccuracyM,
        courseDeg: _lastBearing,
        speedMps: 0,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      ));
      return;
    }
    final p = walker.positionAt(_state.cumulativeM);
    _lastBearing = p.bearingDeg;
    final speed = _state.isPlaying
        ? _state.routeBaseSpeedMps * _state.speedMultiplier
        : 0.0;
    _controller.add(UserLocation(
      lat: p.latLng.latitude,
      lng: p.latLng.longitude,
      horizontalAccuracyM: kPlaybackFakeAccuracyM,
      courseDeg: p.bearingDeg,
      speedMps: speed,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    ));
  }
}
