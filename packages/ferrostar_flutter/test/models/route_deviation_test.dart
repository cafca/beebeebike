import 'package:flutter_test/flutter_test.dart';
import 'package:ferrostar_flutter/src/models/route_deviation.dart';

void main() {
  test('RouteDeviation round-trips', () {
    final json = {
      'deviation_m': 87.0,
      'duration_off_route_ms': 12000,
      'user_location': {
        'lat': 52.52,
        'lng': 13.405,
        'horizontal_accuracy_m': 5.0,
        'course_deg': null,
        'speed_mps': null,
        'timestamp_ms': 1744800000000,
      },
    };
    final d = RouteDeviation.fromJson(json);
    expect(d.deviationM, 87.0);
    expect(d.durationOffRouteMs, 12000);
    expect(d.userLocation.lat, 52.52);
    expect(d.toJson(), json);
  });
}
