import 'dart:async';

import 'package:beebeebike/navigation/navigation_service.dart';
import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:ferrostar_flutter/src/ferrostar_flutter_platform.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFerrostarFlutterPlatform extends FerrostarFlutterPlatform {
  final _deviationCtrl = StreamController<RouteDeviation>.broadcast();
  final _stateCtrl = StreamController<NavigationState>.broadcast();
  final _spokenCtrl = StreamController<SpokenInstruction>.broadcast();
  int replaceRouteCalls = 0;

  void emitDeviation(RouteDeviation d) => _deviationCtrl.add(d);
  void emitState(NavigationState s) => _stateCtrl.add(s);
  void emitSpoken(SpokenInstruction s) => _spokenCtrl.add(s);

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
      _spokenCtrl.stream;

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
      locationStreamFactory: () => const Stream.empty(),
      speakInstruction: (_) async {},
    );
    addTearDown(service.dispose);

    await service.start(
      origin: const WaypointInput(lat: 52.52, lng: 13.405),
      destination: const WaypointInput(lat: 52.51, lng: 13.45),
    );

    fakePlatform.emitDeviation(
      const RouteDeviation(
        deviationM: 87,
        durationOffRouteMs: 12000,
        userLocation: UserLocation(
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

  test(
      'speakInstruction is called once per uuid even when the stream re-emits',
      () async {
    final fakePlatform = FakeFerrostarFlutterPlatform();
    final fakeController = FerrostarController('test', fakePlatform);

    final spoken = <String>[];
    final service = NavigationService(
      createController: (osrmJson, waypoints) async => fakeController,
      loadNavigationRoute: ({required origin, required destination}) async => {
        'routes': [
          {'distance': 1234}
        ]
      },
      locationStreamFactory: () => const Stream.empty(),
      speakInstruction: (text) async {
        spoken.add(text);
      },
    );
    addTearDown(service.dispose);

    await service.start(
      origin: const WaypointInput(lat: 52.52, lng: 13.405),
      destination: const WaypointInput(lat: 52.51, lng: 13.45),
    );

    const first = SpokenInstruction(
      uuid: 'u1',
      text: 'In 200 meters, turn left.',
      triggerDistanceM: 200,
      emittedAtMs: 1,
    );
    const second = SpokenInstruction(
      uuid: 'u2',
      text: 'Turn right now.',
      triggerDistanceM: 20,
      emittedAtMs: 2,
    );

    // Same uuid emitted many times (one per GPS tick in real usage).
    fakePlatform
      ..emitSpoken(first)
      ..emitSpoken(first)
      ..emitSpoken(first);
    await pumpEventQueue();

    // Next instruction with a different uuid.
    fakePlatform
      ..emitSpoken(second)
      ..emitSpoken(second);
    await pumpEventQueue();

    expect(spoken, [first.text, second.text]);
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
      locationStreamFactory: () => const Stream.empty(),
      speakInstruction: (_) async {},
    );
    addTearDown(service.dispose);

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

  test('toggles wakelock on start and dispose', () async {
    final fakePlatform = FakeFerrostarFlutterPlatform();
    final fakeController = FerrostarController('test', fakePlatform);

    final toggles = <bool>[];
    final service = NavigationService(
      createController: (osrmJson, waypoints) async => fakeController,
      loadNavigationRoute: ({required origin, required destination}) async => {
        'routes': [
          {'distance': 1234}
        ]
      },
      locationStreamFactory: () => const Stream.empty(),
      speakInstruction: (_) async {},
      setWakelock: ({required enabled}) async {
        toggles.add(enabled);
      },
    );

    await service.start(
      origin: const WaypointInput(lat: 52.52, lng: 13.405),
      destination: const WaypointInput(lat: 52.51, lng: 13.45),
    );
    expect(toggles, [true]);

    await service.dispose();
    expect(toggles, [true, false]);
  });
}
