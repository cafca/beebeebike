import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

UserLocation positionToUserLocation(Position p) => UserLocation(
      lat: p.latitude,
      lng: p.longitude,
      horizontalAccuracyM: p.accuracy >= 0 ? p.accuracy : 0,
      courseDeg: p.heading >= 0 ? p.heading : null,
      speedMps: p.speed >= 0 ? p.speed : null,
      timestampMs: p.timestamp.millisecondsSinceEpoch,
    );

UserLocation maplibreToUserLocation(ml.UserLocation l) {
  // CLLocation course is -1 when heading is unknown (e.g. user stationary).
  // The Swift bridge traps on UInt16(-1.0); drop sentinel + non-finite values.
  final b = l.bearing;
  final course = (b != null && b.isFinite && b >= 0 && b <= 360) ? b : null;
  final s = l.speed;
  final speed = (s != null && s.isFinite && s >= 0) ? s : null;
  final acc = l.horizontalAccuracy;
  return UserLocation(
    lat: l.position.latitude,
    lng: l.position.longitude,
    horizontalAccuracyM: (acc != null && acc.isFinite && acc >= 0) ? acc : 0,
    courseDeg: course,
    speedMps: speed,
    timestampMs: l.timestamp.millisecondsSinceEpoch,
  );
}
