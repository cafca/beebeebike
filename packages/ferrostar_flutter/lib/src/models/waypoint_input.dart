import 'package:freezed_annotation/freezed_annotation.dart';

part 'waypoint_input.freezed.dart';
part 'waypoint_input.g.dart';

/// How the navigation core should treat a waypoint when matching progress
/// and emitting completion.
enum WaypointKind {
  /// A stop the user must arrive at; reaching it advances the trip and
  /// (for the last one) completes navigation.
  @JsonValue('break')
  breakPoint,

  /// An intermediate point the route should pass through but not "arrive"
  /// at; useful for shaping routes without visible stops.
  @JsonValue('via_point')
  viaPoint,
}

/// Input description of a waypoint passed to the navigation core when
/// creating a controller. Note this is the *input* — distinct from any
/// internal waypoint representation in the core.
@freezed
class WaypointInput with _$WaypointInput {
  /// Creates a [WaypointInput].
  const factory WaypointInput({
    /// Latitude in WGS84 degrees.
    required double lat,

    /// Longitude in WGS84 degrees.
    required double lng,

    /// How the core should treat this waypoint. Defaults to
    /// [WaypointKind.breakPoint].
    @Default(WaypointKind.breakPoint) WaypointKind kind,
  }) = _WaypointInput;

  /// Decodes a waypoint input from its JSON representation.
  factory WaypointInput.fromJson(Map<String, dynamic> json) =>
      _$WaypointInputFromJson(json);
}
