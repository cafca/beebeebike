// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'navigation_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$StepRefImpl _$$StepRefImplFromJson(Map<String, dynamic> json) =>
    _$StepRefImpl(
      index: (json['index'] as num).toInt(),
      roadName: json['road_name'] as String,
    );

Map<String, dynamic> _$$StepRefImplToJson(_$StepRefImpl instance) =>
    <String, dynamic>{'index': instance.index, 'road_name': instance.roadName};

_$NavigationStateImpl _$$NavigationStateImplFromJson(
  Map<String, dynamic> json,
) => _$NavigationStateImpl(
  status: $enumDecode(_$TripStatusEnumMap, json['status']),
  isOffRoute: json['is_off_route'] as bool,
  snappedLocation: json['snapped_location'] == null
      ? null
      : UserLocation.fromJson(json['snapped_location'] as Map<String, dynamic>),
  progress: json['progress'] == null
      ? null
      : TripProgress.fromJson(json['progress'] as Map<String, dynamic>),
  currentVisual: json['current_visual'] == null
      ? null
      : VisualInstruction.fromJson(
          json['current_visual'] as Map<String, dynamic>,
        ),
  currentStep: json['current_step'] == null
      ? null
      : StepRef.fromJson(json['current_step'] as Map<String, dynamic>),
);

Map<String, dynamic> _$$NavigationStateImplToJson(
  _$NavigationStateImpl instance,
) => <String, dynamic>{
  'status': _$TripStatusEnumMap[instance.status]!,
  'is_off_route': instance.isOffRoute,
  'snapped_location': instance.snappedLocation?.toJson(),
  'progress': instance.progress?.toJson(),
  'current_visual': instance.currentVisual?.toJson(),
  'current_step': instance.currentStep?.toJson(),
};

const _$TripStatusEnumMap = {
  TripStatus.idle: 'idle',
  TripStatus.navigating: 'navigating',
  TripStatus.complete: 'complete',
};
