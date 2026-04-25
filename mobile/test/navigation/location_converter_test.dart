import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

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

  ml.UserLocation mlLoc({
    double? bearing,
    double? speed,
    double? accuracy,
  }) =>
      ml.UserLocation(
        position: const ml.LatLng(52.52, 13.405),
        altitude: 0,
        bearing: bearing,
        speed: speed,
        horizontalAccuracy: accuracy,
        verticalAccuracy: 0,
        timestamp: DateTime.fromMillisecondsSinceEpoch(2000),
        heading: null,
      );

  test('maplibreToUserLocation drops bearing=-1 (CLLocation unknown sentinel)',
      () {
    // Swift FFI traps on UInt16(-1.0). The Dart-side guard prevents the value
    // from reaching the bridge.
    final r = maplibreToUserLocation(mlLoc(bearing: -1, speed: 4.0));
    expect(r.courseDeg, isNull);
    expect(r.speedMps, 4.0);
  });

  test('maplibreToUserLocation drops non-finite bearing/speed/accuracy', () {
    final r =
        maplibreToUserLocation(mlLoc(bearing: double.nan, speed: double.infinity, accuracy: double.nan));
    expect(r.courseDeg, isNull);
    expect(r.speedMps, isNull);
    expect(r.horizontalAccuracyM, 0);
  });

  test('maplibreToUserLocation passes valid bearing/speed through', () {
    final r = maplibreToUserLocation(mlLoc(bearing: 90, speed: 3.0, accuracy: 5));
    expect(r.courseDeg, 90);
    expect(r.speedMps, 3.0);
    expect(r.horizontalAccuracyM, 5);
  });
}
