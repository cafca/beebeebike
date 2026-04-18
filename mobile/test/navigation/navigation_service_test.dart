import 'dart:async';

import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:ferrostar_flutter/src/ferrostar_flutter_platform.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beebeebike/navigation/navigation_service.dart';

class FakeFerrostarFlutterPlatform extends FerrostarFlutterPlatform {
  final _deviationCtrl = StreamController<RouteDeviation>.broadcast();
  final _stateCtrl = StreamController<NavigationState>.broadcast();
  int replaceRouteCalls = 0;

  void emitDeviation(RouteDeviation d) => _deviationCtrl.add(d);
  void emitState(NavigationState s) => _stateCtrl.add(s);

  @override
  Future<String> createController({
    required Map<String, dynamic> osrmJson,
    required List<WaypointInput> waypoints,
    required NavigationConfig config,
  }) async =>
      'fake-id';

  @override
  Future<void> updateLocation({
    required String controllerId,
    required UserLocation location,
  }) async {}

  @override
  Future<void> replaceRoute({
    required String controllerId,
    required Map<String, dynamic> osrmJson,
  }) async {
    replaceRouteCalls++;
  }

  @override
  Future<void> dispose({required String controllerId}) async {}

  @override
  Stream<NavigationState> stateStream({required String controllerId}) =>
      _stateCtrl.stream;

  @override
  Stream<SpokenInstruction> spokenInstructionStream(
          {required String controllerId}) =>
      const Stream.empty();

  @override
  Stream<RouteDeviation> deviationStream({required String controllerId}) =>
      _deviationCtrl.stream;
}

void main() {
  test('reroutes by calling replaceRoute when deviation stream emits', () async {
    final fakePlatform = FakeFerrostarFlutterPlatform();
    final fakeController = FerrostarController('test', fakePlatform);

    final service = NavigationService(
      createController: (osrmJson, waypoints) async => fakeController,
      loadNavigationRoute: ({required origin, required destination}) async => {
        'routes': [
          {'distance': 1234}
        ]
      },
      locationStream: () => const Stream.empty(),
      speakInstruction: (_) async {},
    );
    addTearDown(() => service.dispose());

    await service.start(
      origin: const WaypointInput(lat: 52.52, lng: 13.405),
      destination: const WaypointInput(lat: 52.51, lng: 13.45),
    );

    fakePlatform.emitDeviation(
      RouteDeviation(
        deviationM: 87,
        durationOffRouteMs: 12000,
        userLocation: const UserLocation(
          lat: 52.521,
          lng: 13.406,
          horizontalAccuracyM: 5,
          timestampMs: 1,
        ),
      ),
    );

    await pumpEventQueue();
    expect(fakePlatform.replaceRouteCalls, 1);
  });

  test('stateStream forwards NavigationState emitted by the controller', () async {
    final fakePlatform = FakeFerrostarFlutterPlatform();
    final fakeController = FerrostarController('test', fakePlatform);

    final service = NavigationService(
      createController: (osrmJson, waypoints) async => fakeController,
      loadNavigationRoute: ({required origin, required destination}) async => {
        'routes': [
          {'distance': 1234}
        ]
      },
      locationStream: () => const Stream.empty(),
      speakInstruction: (_) async {},
    );
    addTearDown(() => service.dispose());

    final received = <NavigationState>[];
    service.stateStream.listen(received.add);

    await service.start(
      origin: const WaypointInput(lat: 52.52, lng: 13.405),
      destination: const WaypointInput(lat: 52.51, lng: 13.45),
    );

    const state = NavigationState(status: TripStatus.navigating, isOffRoute: false);
    fakePlatform.emitState(state);
    await pumpEventQueue();

    expect(received, [state]);
  });
}
