import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:geolocator/geolocator.dart';

UserLocation positionToUserLocation(Position p) => UserLocation(
      lat: p.latitude,
      lng: p.longitude,
      horizontalAccuracyM: p.accuracy >= 0 ? p.accuracy : 0,
      courseDeg: p.heading >= 0 ? p.heading : null,
      speedMps: p.speed >= 0 ? p.speed : null,
      timestampMs: p.timestamp.millisecondsSinceEpoch,
    );
