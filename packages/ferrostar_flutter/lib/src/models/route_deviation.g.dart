// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_deviation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RouteDeviationImpl _$$RouteDeviationImplFromJson(Map<String, dynamic> json) =>
    _$RouteDeviationImpl(
      deviationM: (json['deviation_m'] as num).toDouble(),
      durationOffRouteMs: (json['duration_off_route_ms'] as num).toInt(),
      userLocation: UserLocation.fromJson(
        json['user_location'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$$RouteDeviationImplToJson(
  _$RouteDeviationImpl instance,
) => <String, dynamic>{
  'deviation_m': instance.deviationM,
  'duration_off_route_ms': instance.durationOffRouteMs,
  'user_location': instance.userLocation.toJson(),
};
