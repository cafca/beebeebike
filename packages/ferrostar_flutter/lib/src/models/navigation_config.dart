import 'package:freezed_annotation/freezed_annotation.dart';

part 'navigation_config.freezed.dart';
part 'navigation_config.g.dart';

/// Tunable thresholds for the Ferrostar navigation core. Defaults match the
/// upstream library; override only when you understand the tradeoffs.
@freezed
class NavigationConfig with _$NavigationConfig {
  /// Creates a [NavigationConfig].
  const factory NavigationConfig({
    /// Distance in meters the user may stray from the route before being
    /// considered off-route.
    @JsonKey(name: 'deviation_threshold_m')
    @Default(50.0)
    double deviationThresholdM,

    /// Time in milliseconds the user must remain past
    /// [deviationThresholdM] before a deviation event is emitted. Filters
    /// transient GPS noise.
    @JsonKey(name: 'deviation_duration_threshold_ms')
    @Default(10000)
    int deviationDurationThresholdMs,

    /// When true, snap reported user locations onto the polyline before
    /// updating progress and emitting state.
    @JsonKey(name: 'snap_user_location_to_route')
    @Default(true)
    bool snapUserLocationToRoute,
  }) = _NavigationConfig;

  /// Decodes a config from its JSON representation.
  factory NavigationConfig.fromJson(Map<String, dynamic> json) =>
      _$NavigationConfigFromJson(json);
}
