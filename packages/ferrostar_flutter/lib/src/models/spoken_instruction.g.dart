// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spoken_instruction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SpokenInstructionImpl _$$SpokenInstructionImplFromJson(
  Map<String, dynamic> json,
) => _$SpokenInstructionImpl(
  uuid: json['uuid'] as String,
  text: json['text'] as String,
  ssml: json['ssml'] as String?,
  triggerDistanceM: (json['trigger_distance_m'] as num).toDouble(),
  emittedAtMs: (json['emitted_at_ms'] as num).toInt(),
);

Map<String, dynamic> _$$SpokenInstructionImplToJson(
  _$SpokenInstructionImpl instance,
) => <String, dynamic>{
  'uuid': instance.uuid,
  'text': instance.text,
  'ssml': instance.ssml,
  'trigger_distance_m': instance.triggerDistanceM,
  'emitted_at_ms': instance.emittedAtMs,
};
