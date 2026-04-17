// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_location.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserLocationImpl _$$UserLocationImplFromJson(Map<String, dynamic> json) =>
    _$UserLocationImpl(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      horizontalAccuracyM: (json['horizontal_accuracy_m'] as num).toDouble(),
      courseDeg: (json['course_deg'] as num?)?.toDouble(),
      speedMps: (json['speed_mps'] as num?)?.toDouble(),
      timestampMs: (json['timestamp_ms'] as num).toInt(),
    );

Map<String, dynamic> _$$UserLocationImplToJson(_$UserLocationImpl instance) =>
    <String, dynamic>{
      'lat': instance.lat,
      'lng': instance.lng,
      'horizontal_accuracy_m': instance.horizontalAccuracyM,
      'course_deg': instance.courseDeg,
      'speed_mps': instance.speedMps,
      'timestamp_ms': instance.timestampMs,
    };
