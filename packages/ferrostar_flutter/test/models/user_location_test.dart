import 'package:flutter_test/flutter_test.dart';
import 'package:ferrostar_flutter/src/models/user_location.dart';

void main() {
  group('UserLocation', () {
    test('round-trips through JSON', () {
      final json = {
        'lat': 52.52,
        'lng': 13.405,
        'horizontal_accuracy_m': 5.0,
        'course_deg': 42.0,
        'speed_mps': 4.3,
        'timestamp_ms': 1744800000000,
      };

      final loc = UserLocation.fromJson(json);
      expect(loc.lat, 52.52);
      expect(loc.lng, 13.405);
      expect(loc.horizontalAccuracyM, 5.0);
      expect(loc.courseDeg, 42.0);
      expect(loc.speedMps, 4.3);
      expect(loc.timestampMs, 1744800000000);

      expect(loc.toJson(), json);
    });

    test('parses with nullable course and speed absent', () {
      final loc = UserLocation.fromJson({
        'lat': 52.52,
        'lng': 13.405,
        'horizontal_accuracy_m': 5.0,
        'timestamp_ms': 1744800000000,
      });
      expect(loc.courseDeg, isNull);
      expect(loc.speedMps, isNull);
    });
  });
}
