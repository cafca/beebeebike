// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'navigation_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NavigationConfigImpl _$$NavigationConfigImplFromJson(
  Map<String, dynamic> json,
) => _$NavigationConfigImpl(
  deviationThresholdM:
      (json['deviation_threshold_m'] as num?)?.toDouble() ?? 50.0,
  deviationDurationThresholdMs:
      (json['deviation_duration_threshold_ms'] as num?)?.toInt() ?? 10000,
  snapUserLocationToRoute: json['snap_user_location_to_route'] as bool? ?? true,
);

Map<String, dynamic> _$$NavigationConfigImplToJson(
  _$NavigationConfigImpl instance,
) => <String, dynamic>{
  'deviation_threshold_m': instance.deviationThresholdM,
  'deviation_duration_threshold_ms': instance.deviationDurationThresholdMs,
  'snap_user_location_to_route': instance.snapUserLocationToRoute,
};
