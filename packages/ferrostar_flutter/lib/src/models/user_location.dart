import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_location.freezed.dart';
part 'user_location.g.dart';

@freezed
class UserLocation with _$UserLocation {
  const factory UserLocation({
    required double lat,
    required double lng,
    @JsonKey(name: 'horizontal_accuracy_m') required double horizontalAccuracyM,
    @JsonKey(name: 'course_deg') double? courseDeg,
    @JsonKey(name: 'speed_mps') double? speedMps,
    @JsonKey(name: 'timestamp_ms') required int timestampMs,
  }) = _UserLocation;

  factory UserLocation.fromJson(Map<String, dynamic> json) =>
      _$UserLocationFromJson(json);
}
