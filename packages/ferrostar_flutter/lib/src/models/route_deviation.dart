import 'package:ferrostar_flutter/src/models/user_location.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'route_deviation.freezed.dart';
part 'route_deviation.g.dart';

/// Event emitted when the user has been off-route past the deviation
/// thresholds. Consumers typically respond by requesting a fresh route.
@freezed
class RouteDeviation with _$RouteDeviation {
  /// Creates a [RouteDeviation].
  const factory RouteDeviation({
    /// Perpendicular distance in meters from the user's location to the
    /// route polyline at detection time.
    @JsonKey(name: 'deviation_m') required double deviationM,

    /// How long the user has been past the deviation distance, in
    /// milliseconds.
    @JsonKey(name: 'duration_off_route_ms') required int durationOffRouteMs,

    /// User location at the moment the deviation was detected.
    @JsonKey(name: 'user_location') required UserLocation userLocation,
  }) = _RouteDeviation;

  /// Decodes a deviation event from its JSON representation.
  factory RouteDeviation.fromJson(Map<String, dynamic> json) =>
      _$RouteDeviationFromJson(json);
}
