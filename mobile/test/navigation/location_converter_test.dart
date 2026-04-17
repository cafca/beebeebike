import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:beebeebike/navigation/location_converter.dart';

void main() {
  test('maps Position fields to UserLocation', () {
    final pos = Position(
      latitude: 52.52,
      longitude: 13.405,
      accuracy: 4.5,
      heading: 270.0,
      speed: 3.2,
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      altitude: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
      speedAccuracy: 0,
    );

    final result = positionToUserLocation(pos);

    expect(result.lat, 52.52);
    expect(result.lng, 13.405);
    expect(result.horizontalAccuracyM, 4.5);
    expect(result.courseDeg, 270.0);
    expect(result.speedMps, 3.2);
    expect(result.timestampMs, 1000);
  });

  test('preserves heading=0 (due north) as courseDeg 0.0', () {
    final pos = Position(
      latitude: 52.52,
      longitude: 13.405,
      accuracy: 5,
      heading: 0.0,
      speed: 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      altitude: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
      speedAccuracy: 0,
    );

    final result = positionToUserLocation(pos);

    expect(result.courseDeg, 0.0);
  });

  test('sets courseDeg/speedMps to null when geolocator returns -1 sentinel', () {
    final pos = Position(
      latitude: 52.52,
      longitude: 13.405,
      accuracy: 5,
      heading: -1.0,
      speed: -1.0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      altitude: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
      speedAccuracy: 0,
    );

    final result = positionToUserLocation(pos);

    expect(result.courseDeg, isNull);
    expect(result.speedMps, isNull);
  });
}
