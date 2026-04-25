import 'package:ferrostar_flutter/src/models/trip_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TripProgress round-trips', () {
    final json = {
      'distance_to_next_maneuver_m': 210.0,
      'distance_remaining_m': 2800.0,
      'duration_remaining_ms': 620000,
    };
    final p = TripProgress.fromJson(json);
    expect(p.distanceToNextManeuverM, 210.0);
    expect(p.distanceRemainingM, 2800.0);
    expect(p.durationRemainingMs, 620000);
    expect(p.toJson(), json);
  });
}
