import 'package:freezed_annotation/freezed_annotation.dart';

part 'visual_instruction.freezed.dart';
part 'visual_instruction.g.dart';

/// On-screen banner instruction for the upcoming maneuver. Mirrors the
/// Mapbox/OSRM "banner" model used by Ferrostar.
@freezed
class VisualInstruction with _$VisualInstruction {
  /// Creates a [VisualInstruction].
  const factory VisualInstruction({
    /// Primary banner text (e.g. the next street name).
    @JsonKey(name: 'primary_text') required String primaryText,

    /// Maneuver type token (e.g. `turn`, `merge`, `roundabout`).
    @JsonKey(name: 'maneuver_type') required String maneuverType,

    /// Distance, in meters, at which this banner becomes active.
    @JsonKey(name: 'trigger_distance_m') required double triggerDistanceM,

    /// Optional secondary banner text (e.g. lane guidance or a sub-name).
    @JsonKey(name: 'secondary_text') String? secondaryText,

    /// Optional modifier on the maneuver (e.g. `left`, `slight right`).
    @JsonKey(name: 'maneuver_modifier') String? maneuverModifier,
  }) = _VisualInstruction;

  /// Decodes a visual instruction from its JSON representation.
  factory VisualInstruction.fromJson(Map<String, dynamic> json) =>
      _$VisualInstructionFromJson(json);
}
