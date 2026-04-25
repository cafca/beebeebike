import 'package:ferrostar_flutter/src/models/navigation_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NavigationState', () {
    test('idle state parses with all nullable fields null', () {
      final json = {
        'status': 'idle',
        'is_off_route': false,
        'snapped_location': null,
        'progress': null,
        'current_visual': null,
        'current_step': null,
      };
      final s = NavigationState.fromJson(json);
      expect(s.status, TripStatus.idle);
      expect(s.isOffRoute, false);
      expect(s.snappedLocation, isNull);
      expect(s.progress, isNull);
      expect(s.currentVisual, isNull);
      expect(s.currentStep, isNull);
      expect(s.toJson(), json);
    });

    test('navigating state parses with all fields populated', () {
      final json = {
        'status': 'navigating',
        'is_off_route': false,
        'snapped_location': {
          'lat': 52.52,
          'lng': 13.405,
          'horizontal_accuracy_m': 5.0,
          'course_deg': 42.0,
          'speed_mps': 4.3,
          'timestamp_ms': 1744800000000,
        },
        'progress': {
          'distance_to_next_maneuver_m': 210.0,
          'distance_remaining_m': 2800.0,
          'duration_remaining_ms': 620000,
        },
        'current_visual': {
          'primary_text': 'Turn left',
          'secondary_text': null,
          'maneuver_type': 'turn',
          'maneuver_modifier': 'left',
          'trigger_distance_m': 200.0,
        },
        'current_step': {
          'index': 3,
          'road_name': 'Kastanienallee',
        },
      };
      final s = NavigationState.fromJson(json);
      expect(s.status, TripStatus.navigating);
      expect(s.snappedLocation!.lat, 52.52);
      expect(s.progress!.distanceRemainingM, 2800.0);
      expect(s.currentVisual!.primaryText, 'Turn left');
      expect(s.currentStep!.index, 3);
      expect(s.currentStep!.roadName, 'Kastanienallee');
    });

    test('complete status parses', () {
      final s = NavigationState.fromJson({
        'status': 'complete',
        'is_off_route': false,
        'snapped_location': null,
        'progress': null,
        'current_visual': null,
        'current_step': null,
      });
      expect(s.status, TripStatus.complete);
    });

    test('unknown status throws', () {
      expect(
        () => NavigationState.fromJson({
          'status': 'banana',
          'is_off_route': false,
          'snapped_location': null,
          'progress': null,
          'current_visual': null,
          'current_step': null,
        }),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
