import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:geolocator/geolocator.dart';

UserLocation positionToUserLocation(Position p) => UserLocation(
      lat: p.latitude,
      lng: p.longitude,
      horizontalAccuracyM: p.accuracy,
      courseDeg: p.heading > 0 ? p.heading : null,
      speedMps: p.speed,
      timestampMs: p.timestamp.millisecondsSinceEpoch,
    );
