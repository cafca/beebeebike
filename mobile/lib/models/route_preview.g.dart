// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_preview.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RoutePreviewImpl _$$RoutePreviewImplFromJson(Map<String, dynamic> json) =>
    _$RoutePreviewImpl(
      geometry: json['geometry'] as Map<String, dynamic>,
      distance: (json['distance'] as num).toDouble(),
      time: (json['time'] as num).toDouble(),
    );

Map<String, dynamic> _$$RoutePreviewImplToJson(_$RoutePreviewImpl instance) =>
    <String, dynamic>{
      'geometry': instance.geometry,
      'distance': instance.distance,
      'time': instance.time,
    };
