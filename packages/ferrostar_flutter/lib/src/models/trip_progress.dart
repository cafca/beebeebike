import 'package:freezed_annotation/freezed_annotation.dart';

part 'trip_progress.freezed.dart';
part 'trip_progress.g.dart';

/// Distance and time progress for the active trip, as computed by the
/// navigation core.
@freezed
class TripProgress with _$TripProgress {
  /// Creates a [TripProgress].
  const factory TripProgress({
    /// Distance, in meters, from the user to the next maneuver.
    @JsonKey(name: 'distance_to_next_maneuver_m')
    required double distanceToNextManeuverM,

    /// Total remaining distance to the destination, in meters.
    @JsonKey(name: 'distance_remaining_m') required double distanceRemainingM,

    /// Estimated remaining trip duration, in milliseconds.
    @JsonKey(name: 'duration_remaining_ms') required int durationRemainingMs,
  }) = _TripProgress;

  /// Decodes a trip progress snapshot from its JSON representation.
  factory TripProgress.fromJson(Map<String, dynamic> json) =>
      _$TripProgressFromJson(json);
}
