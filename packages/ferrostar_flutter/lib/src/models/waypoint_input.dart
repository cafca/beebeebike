import 'package:freezed_annotation/freezed_annotation.dart';

part 'waypoint_input.freezed.dart';
part 'waypoint_input.g.dart';

enum WaypointKind {
  @JsonValue('break') breakPoint,
  @JsonValue('via_point') viaPoint,
}

@freezed
class WaypointInput with _$WaypointInput {
  const factory WaypointInput({
    required double lat,
    required double lng,
    @Default(WaypointKind.breakPoint) WaypointKind kind,
  }) = _WaypointInput;

  factory WaypointInput.fromJson(Map<String, dynamic> json) =>
      _$WaypointInputFromJson(json);
}
