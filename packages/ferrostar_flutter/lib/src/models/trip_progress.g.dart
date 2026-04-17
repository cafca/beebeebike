// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TripProgressImpl _$$TripProgressImplFromJson(Map<String, dynamic> json) =>
    _$TripProgressImpl(
      distanceToNextManeuverM: (json['distance_to_next_maneuver_m'] as num)
          .toDouble(),
      distanceRemainingM: (json['distance_remaining_m'] as num).toDouble(),
      durationRemainingMs: (json['duration_remaining_ms'] as num).toInt(),
    );

Map<String, dynamic> _$$TripProgressImplToJson(_$TripProgressImpl instance) =>
    <String, dynamic>{
      'distance_to_next_maneuver_m': instance.distanceToNextManeuverM,
      'distance_remaining_m': instance.distanceRemainingM,
      'duration_remaining_ms': instance.durationRemainingMs,
    };
