import 'dart:async';

import 'package:beebeebike/dev/playback_constants.dart';
import 'package:beebeebike/dev/playback_engine.dart';
import 'package:beebeebike/dev/playback_state.dart';
import 'package:beebeebike/dev/polyline_walker.dart';
import 'package:beebeebike/models/route_preview.dart';
import 'package:beebeebike/providers/route_provider.dart';
import 'package:ferrostar_flutter/ferrostar_flutter.dart' show UserLocation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart' hide UserLocation;

final playbackEngineProvider = Provider<PlaybackEngine>((ref) {
  final engine = PlaybackEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

class PlaybackController extends Notifier<PlaybackState> {
  StreamSubscription<UserLocation>? _engineSub;

  @override
  PlaybackState build() {
    final engine = ref.watch(playbackEngineProvider);
    final preview = ref.watch(routeControllerProvider.select((s) => s.preview));
    if (preview != null) {
      _seedFrom(preview, engine);
    } else {
      engine.clearRoute();
    }
    unawaited(_engineSub?.cancel());
    _engineSub = engine.stream.listen((_) {
      state = engine.state;
    });
    ref.onDispose(() => unawaited(_engineSub?.cancel()));
    return engine.state;
  }

  void _seedFrom(RoutePreview preview, PlaybackEngine engine) {
    final coords = (preview.geometry['coordinates'] as List)
        .map((c) => LatLng((c as List)[1] as double, c[0] as double))
        .toList();
    if (coords.length < 2) {
      engine.clearRoute();
      return;
    }
    // preview.time is in milliseconds (see home_eta_provider.dart, route_sheet.dart).
    final timeSeconds = preview.time / 1000.0;
    final baseSpeed =
        timeSeconds > 0 ? preview.distance / timeSeconds : 1.0;
    engine.setRoute(
      walker: PolylineWalker(coords),
      routeBaseSpeedMps: baseSpeed,
    );
  }

  PlaybackEngine get _engine => ref.read(playbackEngineProvider);

  void play() {
    _engine.play();
    state = _engine.state;
  }

  void pause() {
    _engine.pause();
    state = _engine.state;
  }

  void restart() {
    _engine.seek(0);
    state = _engine.state;
  }

  void stepForward() {
    _engine.step(kPlaybackStepMeters);
    state = _engine.state;
  }

  void stepBack() {
    _engine.step(-kPlaybackStepMeters);
    state = _engine.state;
  }

  void seek(double cumulativeM) {
    _engine.seek(cumulativeM);
    state = _engine.state;
  }

  void cycleSpeed() {
    const list = kPlaybackSpeedMultipliers;
    final current = state.speedMultiplier;
    final idx = list.indexOf(current);
    final next = list[(idx + 1) % list.length];
    _engine.setSpeedMultiplier(next);
    state = _engine.state;
  }

  void setOverride(LatLng latLng) {
    _engine.setOverridePosition(latLng);
    state = _engine.state;
  }

  void clearOverride() {
    _engine.clearOverride();
    state = _engine.state;
  }

  /// Returns the puck's current map latlng — interpolated from the polyline
  /// at `state.cumulativeM`, or the current override if set. Returns
  /// `LatLng(0, 0)` if no route is loaded; callers should check
  /// `state.routeLengthM > 0` first.
  LatLng currentLatLng() {
    final preview =
        ref.read(routeControllerProvider.select((s) => s.preview));
    if (preview == null) return const LatLng(0, 0);
    final override = state.overrideLatLng;
    if (override != null) return override;
    final coords = (preview.geometry['coordinates'] as List)
        .map((c) => LatLng((c as List)[1] as double, c[0] as double))
        .toList();
    if (coords.length < 2) return const LatLng(0, 0);
    return PolylineWalker(coords).positionAt(state.cumulativeM).latLng;
  }
}

final playbackControllerProvider =
    NotifierProvider<PlaybackController, PlaybackState>(PlaybackController.new);
