import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

part 'playback_state.freezed.dart';

@freezed
class PlaybackState with _$PlaybackState {
  const factory PlaybackState({
    @Default(false) bool isPlaying,
    @Default(0.0) double cumulativeM,
    @Default(1.0) double speedMultiplier,
    LatLng? overrideLatLng,
    @Default(0.0) double routeLengthM,
    @Default(0.0) double routeBaseSpeedMps,
  }) = _PlaybackState;
}
