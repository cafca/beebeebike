// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'geocode_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GeocodeResultImpl _$$GeocodeResultImplFromJson(Map<String, dynamic> json) =>
    _$GeocodeResultImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      label: json['label'] as String,
      lng: (json['lng'] as num).toDouble(),
      lat: (json['lat'] as num).toDouble(),
      street: json['street'] as String?,
      housenumber: json['housenumber'] as String?,
    );

Map<String, dynamic> _$$GeocodeResultImplToJson(_$GeocodeResultImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'label': instance.label,
      'lng': instance.lng,
      'lat': instance.lat,
      'street': instance.street,
      'housenumber': instance.housenumber,
    };
