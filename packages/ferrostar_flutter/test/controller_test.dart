import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:ferrostar_flutter/src/ferrostar_flutter_platform.dart';

class _FakePlatform extends FerrostarFlutterPlatform {
  String? lastCall;
  final stateCtrl = StreamController<NavigationState>.broadcast();
  final spokenCtrl = StreamController<SpokenInstruction>.broadcast();
  final devCtrl = StreamController<RouteDeviation>.broadcast();

  @override
  Future<String> createController({
    required Map<String, dynamic> osrmJson,
    required List<WaypointInput> waypoints,
    required NavigationConfig config,
  }) async {
    lastCall = 'createController';
    return 'test-id';
  }

  @override
  Future<void> updateLocation({
    required String controllerId,
    required UserLocation location,
  }) async =>
      lastCall = 'updateLocation';

  @override
  Future<void> replaceRoute({
    required String controllerId,
    required Map<String, dynamic> osrmJson,
  }) async =>
      lastCall = 'replaceRoute';

  @override
  Future<void> dispose({required String controllerId}) async {
    lastCall = 'dispose';
    await stateCtrl.close();
    await spokenCtrl.close();
    await devCtrl.close();
  }

  @override
  Stream<NavigationState> stateStream({required String controllerId}) =>
      stateCtrl.stream;

  @override
  Stream<SpokenInstruction> spokenInstructionStream(
          {required String controllerId}) =>
      spokenCtrl.stream;

  @override
  Stream<RouteDeviation> deviationStream({required String controllerId}) =>
      devCtrl.stream;
}

void main() {
  late _FakePlatform fake;

  setUp(() {
    fake = _FakePlatform();
    FerrostarFlutterPlatform.instance = fake;
  });

  test('createController goes through facade', () async {
    final c = await FerrostarFlutter.instance.createController(
      osrmJson: {'code': 'Ok', 'routes': []},
      waypoints: [const WaypointInput(lat: 52.52, lng: 13.405)],
    );
    expect(c.id, 'test-id');
    expect(fake.lastCall, 'createController');
  });

  test('updateLocation after dispose throws StateError', () async {
    final c = await FerrostarFlutter.instance.createController(
      osrmJson: {'code': 'Ok', 'routes': []},
      waypoints: [const WaypointInput(lat: 52.52, lng: 13.405)],
    );
    await c.dispose();
    expect(
      () => c.updateLocation(const UserLocation(
        lat: 0,
        lng: 0,
        horizontalAccuracyM: 1,
        timestampMs: 0,
      )),
      throwsStateError,
    );
  });
}
