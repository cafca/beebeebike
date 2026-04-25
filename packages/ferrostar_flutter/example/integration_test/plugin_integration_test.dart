import 'dart:convert';

import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('create -> update -> receive navigating state', (tester) async {
    final osrmStr = await rootBundle.loadString('assets/sample_osrm_route.json');
    final osrm = json.decode(osrmStr) as Map<String, dynamic>;

    final ctrl = await FerrostarFlutter.instance.createController(
      osrmJson: osrm,
      waypoints: [
        const WaypointInput(lat: 59.442643, lng: 24.765368),
        const WaypointInput(lat: 59.452226, lng: 24.730034),
      ],
    );

    final stateFuture = ctrl.stateStream
        .firstWhere((s) => s.status == TripStatus.navigating)
        .timeout(const Duration(seconds: 5));

    await ctrl.updateLocation(UserLocation(
      lat: 59.4429,
      lng: 24.7653,
      horizontalAccuracyM: 5,
      courseDeg: 315,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    ));

    final state = await stateFuture;
    expect(state.status, TripStatus.navigating);
    expect(state.progress, isNotNull);

    await ctrl.dispose();
  });

  testWidgets('replaceRoute does not throw', (tester) async {
    final osrmStr = await rootBundle.loadString('assets/sample_osrm_route.json');
    final osrm = json.decode(osrmStr) as Map<String, dynamic>;

    final ctrl = await FerrostarFlutter.instance.createController(
      osrmJson: osrm,
      waypoints: [
        const WaypointInput(lat: 59.442643, lng: 24.765368),
        const WaypointInput(lat: 59.452226, lng: 24.730034),
      ],
    );
    await ctrl.replaceRoute(osrm);
    await ctrl.dispose();
  });
}
