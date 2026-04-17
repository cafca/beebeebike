import 'package:flutter_test/flutter_test.dart';
import 'package:ferrostar_flutter/src/models/waypoint_input.dart';
import 'package:ferrostar_flutter/src/models/navigation_config.dart';

void main() {
  test('WaypointInput serializes', () {
    const w = WaypointInput(lat: 52.52, lng: 13.405, kind: WaypointKind.viaPoint);
    expect(w.toJson(), {'lat': 52.52, 'lng': 13.405, 'kind': 'via_point'});
  });

  test('WaypointInput kinds', () {
    expect(WaypointInput.fromJson({'lat': 0.0, 'lng': 0.0, 'kind': 'break'}).kind,
        WaypointKind.breakPoint);
  });

  test('NavigationConfig default serializes with sane defaults', () {
    const c = NavigationConfig();
    final j = c.toJson();
    expect(j['deviation_threshold_m'], 50.0);
    expect(j['deviation_duration_threshold_ms'], 10000);
    expect(j['snap_user_location_to_route'], true);
  });
}
