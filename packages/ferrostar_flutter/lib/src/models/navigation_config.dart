import 'package:freezed_annotation/freezed_annotation.dart';

part 'navigation_config.freezed.dart';
part 'navigation_config.g.dart';

@freezed
class NavigationConfig with _$NavigationConfig {
  const factory NavigationConfig({
    @JsonKey(name: 'deviation_threshold_m') @Default(50.0) double deviationThresholdM,
    @JsonKey(name: 'deviation_duration_threshold_ms') @Default(10000) int deviationDurationThresholdMs,
    @JsonKey(name: 'snap_user_location_to_route') @Default(true) bool snapUserLocationToRoute,
  }) = _NavigationConfig;

  factory NavigationConfig.fromJson(Map<String, dynamic> json) =>
      _$NavigationConfigFromJson(json);
}
