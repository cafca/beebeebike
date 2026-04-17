import 'package:freezed_annotation/freezed_annotation.dart';

part 'trip_progress.freezed.dart';
part 'trip_progress.g.dart';

@freezed
class TripProgress with _$TripProgress {
  const factory TripProgress({
    @JsonKey(name: 'distance_to_next_maneuver_m') required double distanceToNextManeuverM,
    @JsonKey(name: 'distance_remaining_m') required double distanceRemainingM,
    @JsonKey(name: 'duration_remaining_ms') required int durationRemainingMs,
  }) = _TripProgress;

  factory TripProgress.fromJson(Map<String, dynamic> json) =>
      _$TripProgressFromJson(json);
}
