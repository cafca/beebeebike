import 'package:freezed_annotation/freezed_annotation.dart';

part 'visual_instruction.freezed.dart';
part 'visual_instruction.g.dart';

@freezed
class VisualInstruction with _$VisualInstruction {
  const factory VisualInstruction({
    @JsonKey(name: 'primary_text') required String primaryText,
    @JsonKey(name: 'secondary_text') String? secondaryText,
    @JsonKey(name: 'maneuver_type') required String maneuverType,
    @JsonKey(name: 'maneuver_modifier') String? maneuverModifier,
    @JsonKey(name: 'trigger_distance_m') required double triggerDistanceM,
  }) = _VisualInstruction;

  factory VisualInstruction.fromJson(Map<String, dynamic> json) =>
      _$VisualInstructionFromJson(json);
}
