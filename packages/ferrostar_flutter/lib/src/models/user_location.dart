import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_location.freezed.dart';
part 'user_location.g.dart';

/// A single GPS fix passed into the navigation core.
@freezed
class UserLocation with _$UserLocation {
  /// Creates a [UserLocation].
  const factory UserLocation({
    /// Latitude in WGS84 degrees.
    required double lat,

    /// Longitude in WGS84 degrees.
    required double lng,

    /// Reported horizontal accuracy of the fix, in meters (1-sigma).
    @JsonKey(name: 'horizontal_accuracy_m')
    required double horizontalAccuracyM,

    /// Wall-clock time of the fix, in milliseconds since epoch.
    @JsonKey(name: 'timestamp_ms') required int timestampMs,

    /// Course over ground in degrees clockwise from true north, when known.
    @JsonKey(name: 'course_deg') double? courseDeg,

    /// Speed over ground in meters per second, when known.
    @JsonKey(name: 'speed_mps') double? speedMps,
  }) = _UserLocation;

  /// Decodes a user location from its JSON representation.
  factory UserLocation.fromJson(Map<String, dynamic> json) =>
      _$UserLocationFromJson(json);
}
