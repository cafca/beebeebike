import 'package:freezed_annotation/freezed_annotation.dart';
import 'user_location.dart';

part 'route_deviation.freezed.dart';
part 'route_deviation.g.dart';

@freezed
class RouteDeviation with _$RouteDeviation {
  const factory RouteDeviation({
    @JsonKey(name: 'deviation_m') required double deviationM,
    @JsonKey(name: 'duration_off_route_ms') required int durationOffRouteMs,
    @JsonKey(name: 'user_location') required UserLocation userLocation,
  }) = _RouteDeviation;

  factory RouteDeviation.fromJson(Map<String, dynamic> json) =>
      _$RouteDeviationFromJson(json);
}
