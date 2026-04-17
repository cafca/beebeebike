// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'waypoint_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WaypointInputImpl _$$WaypointInputImplFromJson(Map<String, dynamic> json) =>
    _$WaypointInputImpl(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      kind:
          $enumDecodeNullable(_$WaypointKindEnumMap, json['kind']) ??
          WaypointKind.breakPoint,
    );

Map<String, dynamic> _$$WaypointInputImplToJson(_$WaypointInputImpl instance) =>
    <String, dynamic>{
      'lat': instance.lat,
      'lng': instance.lng,
      'kind': _$WaypointKindEnumMap[instance.kind]!,
    };

const _$WaypointKindEnumMap = {
  WaypointKind.breakPoint: 'break',
  WaypointKind.viaPoint: 'via_point',
};
