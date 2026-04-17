// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visual_instruction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$VisualInstructionImpl _$$VisualInstructionImplFromJson(
  Map<String, dynamic> json,
) => _$VisualInstructionImpl(
  primaryText: json['primary_text'] as String,
  secondaryText: json['secondary_text'] as String?,
  maneuverType: json['maneuver_type'] as String,
  maneuverModifier: json['maneuver_modifier'] as String?,
  triggerDistanceM: (json['trigger_distance_m'] as num).toDouble(),
);

Map<String, dynamic> _$$VisualInstructionImplToJson(
  _$VisualInstructionImpl instance,
) => <String, dynamic>{
  'primary_text': instance.primaryText,
  'secondary_text': instance.secondaryText,
  'maneuver_type': instance.maneuverType,
  'maneuver_modifier': instance.maneuverModifier,
  'trigger_distance_m': instance.triggerDistanceM,
};
