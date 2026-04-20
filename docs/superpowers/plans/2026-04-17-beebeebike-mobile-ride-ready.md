# BeeBeeBike Mobile Ride-Ready Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire real GPS, TTS, and live navigation state into the iOS app so it can guide a real bike ride.

**Architecture:** Three stubs in `navigation_provider.dart` are replaced with real platform integrations (`geolocator`, `flutter_tts`). `NavigationService` gains a `stateStream` getter (backed by a broadcast `StreamController`) so the UI can watch live `NavigationState`. `NavigationScreen` becomes a `ConsumerStatefulWidget` that starts/stops the service in `initState`/`dispose` and renders turn instructions from real state.

**Tech Stack:** Flutter/Dart, Riverpod 2.x, `geolocator ^13.0.1`, `flutter_tts ^4.0.2`, `ferrostar_flutter` (path dep), `integration_test` (sdk: flutter)

---

## File Map

| Path | Action | Responsibility |
|------|--------|----------------|
| `mobile/lib/navigation/location_converter.dart` | Create | Pure function `positionToUserLocation(Position) → UserLocation` |
| `mobile/test/navigation/location_converter_test.dart` | Create | Unit tests for the conversion |
| `mobile/lib/navigation/navigation_service.dart` | Modify | Add `_stateController`, `_stateSub`, `stateStream` getter |
| `mobile/test/navigation/navigation_service_test.dart` | Modify | Add test verifying stateStream forwards controller state |
| `mobile/lib/providers/navigation_provider.dart` | Modify | Wire GPS stream, TTS speak, add `flutterTtsProvider` + `navigationStateProvider` |
| `mobile/test/providers/navigation_provider_test.dart` | Create | Unit test: speakInstruction calls FlutterTts.speak |
| `mobile/lib/screens/navigation_screen.dart` | Rewrite | ConsumerStatefulWidget watching live NavigationState |
| `mobile/lib/widgets/turn_banner.dart` | Modify | Add optional `icon` parameter |
| `mobile/test/screens/navigation_screen_test.dart` | Create | Widget test: live state renders correctly |
| `mobile/ios/Runner/Info.plist` | Modify | Add `NSLocationWhenInUseUsageDescription` |
| `mobile/pubspec.yaml` | Modify | Add `integration_test` to dev_dependencies |
| `mobile/integration_test/navigation_smoke_test.dart` | Create | Boot app, assert Scaffold renders |
| `.github/workflows/ci-mobile.yml` | Modify | Add `test-mobile-ios` simulator job |

---

## Task 1: GPS stream wiring

**Files:**
- Create: `mobile/lib/navigation/location_converter.dart`
- Create: `mobile/test/navigation/location_converter_test.dart`
- Modify: `mobile/lib/providers/navigation_provider.dart`
- Modify: `mobile/ios/Runner/Info.plist`

- [ ] **Step 1: Write failing test**

Create `mobile/test/navigation/location_converter_test.dart`:

```dart
import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

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

  test('sets courseDeg to null when heading is zero', () {
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

    expect(result.courseDeg, isNull);
  });
}
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
cd mobile && flutter test test/navigation/location_converter_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: 'package:beebeebike/navigation/location_converter.dart'`

- [ ] **Step 3: Create `location_converter.dart`**

```dart
import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:geolocator/geolocator.dart';

UserLocation positionToUserLocation(Position p) => UserLocation(
      lat: p.latitude,
      lng: p.longitude,
      horizontalAccuracyM: p.accuracy,
      courseDeg: p.heading > 0 ? p.heading : null,
      speedMps: p.speed,
      timestampMs: p.timestamp.millisecondsSinceEpoch,
    );
```

- [ ] **Step 4: Run test — expect PASS**

```bash
cd mobile && flutter test test/navigation/location_converter_test.dart
```

Expected: All tests pass.

- [ ] **Step 5: Wire GPS into provider**

Replace the stub in `mobile/lib/providers/navigation_provider.dart`:

```dart
import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../api/client.dart';
import '../api/routing_api.dart';
import '../navigation/location_converter.dart';
import '../navigation/navigation_service.dart';

final navigationServiceProvider = Provider<NavigationService>((ref) {
  final dio = ref.watch(dioProvider);
  final routingApi = RoutingApi(dio);
  return NavigationService(
    createController: (osrmJson, waypoints) =>
        FerrostarFlutter.instance.createController(
          osrmJson: osrmJson,
          waypoints: waypoints,
        ),
    loadNavigationRoute: ({required origin, required destination}) =>
        routingApi.computeNavigationRoute(origin, destination),
    locationStream: Geolocator.getPositionStream().map(positionToUserLocation),
    speakInstruction: (_) async {},
  );
});
```

- [ ] **Step 6: Add iOS location permission to `mobile/ios/Runner/Info.plist`**

Add this key/string pair inside the root `<dict>`, after `CADisableMinimumFrameDurationOnPhone`:

```xml
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>BeeBeeBike needs your location to navigate your bike route.</string>
```

- [ ] **Step 7: Run full unit test suite — expect PASS**

```bash
cd mobile && flutter test test/
```

Expected: All tests pass (existing navigation_service_test.dart etc).

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/navigation/location_converter.dart \
        mobile/test/navigation/location_converter_test.dart \
        mobile/lib/providers/navigation_provider.dart \
        mobile/ios/Runner/Info.plist
git commit -m "feat(mobile): wire real geolocator stream into NavigationService"
```

---

## Task 2: TTS wiring

**Files:**
- Create: `mobile/test/providers/navigation_provider_test.dart`
- Modify: `mobile/lib/providers/navigation_provider.dart`

- [ ] **Step 1: Write failing test**

Create `mobile/test/providers/navigation_provider_test.dart`:

```dart
import 'package:beebeebike/app.dart';
import 'package:beebeebike/config/app_config.dart';
import 'package:beebeebike/providers/navigation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterTts extends Mock implements FlutterTts {}

void main() {
  test('speakInstruction calls FlutterTts.speak with the given text', () async {
    final mockTts = MockFlutterTts();
    when(() => mockTts.speak(any())).thenAnswer((_) async => 1);

    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            apiBaseUrl: 'http://localhost',
            tileStyleUrl: 'http://localhost/tiles',
          ),
        ),
        flutterTtsProvider.overrideWithValue(mockTts),
      ],
    );
    addTearDown(container.dispose);

    final service = container.read(navigationServiceProvider);
    await service.speakInstruction('Turn left');

    verify(() => mockTts.speak('Turn left')).called(1);
  });
}
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
cd mobile && flutter test test/providers/navigation_provider_test.dart
```

Expected: FAIL — `flutterTtsProvider` is not defined.

- [ ] **Step 3: Add `flutterTtsProvider` and wire TTS into provider**

Replace `mobile/lib/providers/navigation_provider.dart` with:

```dart
import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';

import '../api/client.dart';
import '../api/routing_api.dart';
import '../navigation/location_converter.dart';
import '../navigation/navigation_service.dart';

final flutterTtsProvider = Provider<FlutterTts>((ref) => FlutterTts());

final navigationServiceProvider = Provider<NavigationService>((ref) {
  final dio = ref.watch(dioProvider);
  final routingApi = RoutingApi(dio);
  final tts = ref.watch(flutterTtsProvider);
  return NavigationService(
    createController: (osrmJson, waypoints) =>
        FerrostarFlutter.instance.createController(
          osrmJson: osrmJson,
          waypoints: waypoints,
        ),
    loadNavigationRoute: ({required origin, required destination}) =>
        routingApi.computeNavigationRoute(origin, destination),
    locationStream: Geolocator.getPositionStream().map(positionToUserLocation),
    speakInstruction: (text) async { await tts.speak(text); },
  );
});
```

- [ ] **Step 4: Run test — expect PASS**

```bash
cd mobile && flutter test test/providers/navigation_provider_test.dart
```

Expected: All tests pass.

- [ ] **Step 5: Run full suite — expect PASS**

```bash
cd mobile && flutter test test/
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/providers/navigation_provider.dart \
        mobile/test/providers/navigation_provider_test.dart
git commit -m "feat(mobile): wire flutter_tts for spoken navigation instructions"
```

---

## Task 3: NavigationService state stream

**Files:**
- Modify: `mobile/lib/navigation/navigation_service.dart`
- Modify: `mobile/test/navigation/navigation_service_test.dart`
- Modify: `mobile/lib/providers/navigation_provider.dart`

- [ ] **Step 1: Write failing test**

In `mobile/test/navigation/navigation_service_test.dart`, add `_stateCtrl` and `emitState` to the existing `FakeFerrostarFlutterPlatform`, and add a new test. The full file becomes:

```dart
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
      locationStream: const Stream.empty(),
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
      locationStream: const Stream.empty(),
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
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
cd mobile && flutter test test/navigation/navigation_service_test.dart
```

Expected: FAIL — `The getter 'stateStream' isn't defined for the class 'NavigationService'`

- [ ] **Step 3: Add stateStream to NavigationService**

Replace `mobile/lib/navigation/navigation_service.dart` with:

```dart
import 'dart:async';

import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter/foundation.dart';

typedef CreateController = Future<FerrostarController> Function(
  Map<String, dynamic> osrmJson,
  List<WaypointInput> waypoints,
);
typedef LoadNavigationRoute = Future<Map<String, dynamic>> Function({
  required List<double> origin,
  required List<double> destination,
});
typedef SpeakInstruction = Future<void> Function(String text);

class NavigationService {
  NavigationService({
    required this.createController,
    required this.loadNavigationRoute,
    required this.locationStream,
    required this.speakInstruction,
  });

  final CreateController createController;
  final LoadNavigationRoute loadNavigationRoute;
  final Stream<UserLocation> locationStream;
  final SpeakInstruction speakInstruction;

  FerrostarController? _controller;
  StreamSubscription<UserLocation>? _locationSub;
  StreamSubscription<SpokenInstruction>? _spokenSub;
  StreamSubscription<RouteDeviation>? _deviationSub;
  StreamSubscription<NavigationState>? _stateSub;
  WaypointInput? _destination;

  final _stateController = StreamController<NavigationState>.broadcast();

  Stream<NavigationState> get stateStream => _stateController.stream;

  Future<void> start({
    required WaypointInput origin,
    required WaypointInput destination,
  }) async {
    await dispose();
    _destination = destination;
    final routeJson = await loadNavigationRoute(
      origin: [origin.lng, origin.lat],
      destination: [destination.lng, destination.lat],
    );
    final waypoints = [origin, destination];
    _controller = await createController(routeJson, waypoints);

    _stateSub = _controller!.stateStream.listen(
      _stateController.add,
      onError: _stateController.addError,
    );

    _spokenSub = _controller!.spokenInstructionStream.listen(
      (instruction) => speakInstruction(instruction.text),
    );

    _deviationSub = _controller!.deviationStream.listen((deviation) async {
      try {
        final dest = _destination;
        if (dest == null) return;
        final rerouteJson = await loadNavigationRoute(
          origin: [deviation.userLocation.lng, deviation.userLocation.lat],
          destination: [dest.lng, dest.lat],
        );
        await _controller!.replaceRoute(rerouteJson);
      } catch (e, st) {
        debugPrint('NavigationService reroute error: $e\n$st');
      }
    });

    _locationSub = locationStream.listen(
      (location) => _controller?.updateLocation(location),
    );
  }

  Future<void> dispose() async {
    await _locationSub?.cancel();
    await _spokenSub?.cancel();
    await _deviationSub?.cancel();
    await _stateSub?.cancel();
    await _controller?.dispose();
    _locationSub = null;
    _spokenSub = null;
    _deviationSub = null;
    _stateSub = null;
    _controller = null;
  }
}
```

- [ ] **Step 4: Run test — expect PASS**

```bash
cd mobile && flutter test test/navigation/navigation_service_test.dart
```

Expected: Both tests pass.

- [ ] **Step 5: Add navigationStateProvider to navigation_provider.dart**

Append to `mobile/lib/providers/navigation_provider.dart` (add after `navigationServiceProvider`):

```dart
final navigationStateProvider = StreamProvider<NavigationState>((ref) {
  return ref.watch(navigationServiceProvider).stateStream;
});
```

- [ ] **Step 6: Run full test suite — expect PASS**

```bash
cd mobile && flutter test test/
```

Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/navigation/navigation_service.dart \
        mobile/test/navigation/navigation_service_test.dart \
        mobile/lib/providers/navigation_provider.dart
git commit -m "feat(mobile): expose NavigationService.stateStream for live nav state"
```

---

## Task 4: Live NavigationScreen

**Files:**
- Create: `mobile/test/screens/navigation_screen_test.dart`
- Modify: `mobile/lib/widgets/turn_banner.dart`
- Rewrite: `mobile/lib/screens/navigation_screen.dart`

- [ ] **Step 1: Write failing test**

Create `mobile/test/screens/navigation_screen_test.dart`:

```dart
import 'package:beebeebike/navigation/navigation_service.dart';
import 'package:beebeebike/providers/navigation_provider.dart';
import 'package:beebeebike/screens/navigation_screen.dart';
import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows live instruction and distance from NavigationState',
      (tester) async {
    const fakeState = NavigationState(
      status: TripStatus.navigating,
      isOffRoute: false,
      currentVisual: VisualInstruction(
        primaryText: 'Turn left onto Test Street',
        maneuverType: 'turn',
        maneuverModifier: 'left',
        triggerDistanceM: 150,
      ),
      progress: TripProgress(
        distanceToNextManeuverM: 150,
        distanceRemainingM: 3200,
        durationRemainingMs: 720000,
      ),
    );

    final fakeService = NavigationService(
      createController: (_, __) => throw UnimplementedError(),
      loadNavigationRoute: ({required origin, required destination}) =>
          throw UnimplementedError(),
      locationStream: const Stream.empty(),
      speakInstruction: (_) async {},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          navigationStateProvider
              .overrideWith((ref) => Stream.value(fakeState)),
          navigationServiceProvider.overrideWithValue(fakeService),
        ],
        child: const MaterialApp(home: NavigationScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Turn left onto Test Street'), findsOneWidget);
    expect(find.text('150 m'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
cd mobile && flutter test test/screens/navigation_screen_test.dart
```

Expected: FAIL — finds hardcoded 'Turn left onto Kastanienallee' but not 'Turn left onto Test Street'.

- [ ] **Step 3: Add `icon` parameter to TurnBanner**

Replace `mobile/lib/widgets/turn_banner.dart`:

```dart
import 'package:flutter/material.dart';

class TurnBanner extends StatelessWidget {
  const TurnBanner({
    super.key,
    required this.primaryText,
    required this.distanceText,
    this.icon = Icons.straight,
  });

  final String primaryText;
  final String distanceText;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2F8F56),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              primaryText,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          Text(distanceText, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Rewrite NavigationScreen**

Replace `mobile/lib/screens/navigation_screen.dart`:

```dart
import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/navigation_provider.dart';
import '../providers/route_provider.dart';
import '../widgets/turn_banner.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  @override
  void initState() {
    super.initState();
    _startNavigation();
  }

  @override
  void dispose() {
    ref.read(navigationServiceProvider).dispose();
    super.dispose();
  }

  Future<void> _startNavigation() async {
    final routeState = ref.read(routeControllerProvider);
    final origin = routeState.origin;
    final destination = routeState.destination;
    if (origin == null || destination == null) return;

    try {
      await ref.read(navigationServiceProvider).start(
            origin: WaypointInput(lat: origin.lat, lng: origin.lng),
            destination:
                WaypointInput(lat: destination.lat, lng: destination.lng),
          );
    } catch (e, st) {
      debugPrint('NavigationScreen: failed to start navigation: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationStateProvider);

    return Scaffold(
      body: Stack(
        children: [
          Container(color: const Color(0xFFCFE3D3)),
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: navState.when(
                loading: () => const TurnBanner(
                  primaryText: 'Starting navigation...',
                  distanceText: '',
                ),
                error: (e, _) => const TurnBanner(
                  primaryText: 'Navigation error',
                  distanceText: '',
                  icon: Icons.error_outline,
                ),
                data: (state) => TurnBanner(
                  primaryText: state.currentVisual?.primaryText ?? 'On route',
                  distanceText: state.progress != null
                      ? _formatDistance(
                          state.progress!.distanceToNextManeuverM)
                      : '',
                  icon: state.currentVisual != null
                      ? _iconForManeuver(
                          state.currentVisual!.maneuverType,
                          state.currentVisual!.maneuverModifier,
                        )
                      : Icons.straight,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    navState.when(
                      loading: () => const Text('Loading...'),
                      error: (_, __) => const Text('—'),
                      data: (state) {
                        final p = state.progress;
                        if (p == null) return const Text('—');
                        return Text(_formatEta(p.durationRemainingMs));
                      },
                    ),
                    Row(
                      children: [
                        const Icon(Icons.volume_up_outlined),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () {
                            ref.read(navigationServiceProvider).dispose();
                            Navigator.of(context).pop();
                          },
                          child: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconForManeuver(String type, String? modifier) {
  if (type == 'turn') {
    if (modifier == 'left') return Icons.turn_left;
    if (modifier == 'right') return Icons.turn_right;
    if (modifier == 'sharp left') return Icons.turn_sharp_left;
    if (modifier == 'sharp right') return Icons.turn_sharp_right;
    if (modifier == 'slight left') return Icons.turn_slight_left;
    if (modifier == 'slight right') return Icons.turn_slight_right;
  }
  if (type == 'arrive') return Icons.flag;
  return Icons.straight;
}

String _formatDistance(double meters) {
  if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
  return '${meters.round()} m';
}

String _formatEta(int durationRemainingMs) {
  final eta =
      DateTime.now().add(Duration(milliseconds: durationRemainingMs));
  final h = eta.hour.toString().padLeft(2, '0');
  final m = eta.minute.toString().padLeft(2, '0');
  final minRemaining = (durationRemainingMs / 60000).round();
  return '$h:$m arrival · $minRemaining min';
}
```

- [ ] **Step 5: Run test — expect PASS**

```bash
cd mobile && flutter test test/screens/navigation_screen_test.dart
```

Expected: All tests pass.

- [ ] **Step 6: Run full suite — expect PASS**

```bash
cd mobile && flutter test test/
```

Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/screens/navigation_screen.dart \
        mobile/lib/widgets/turn_banner.dart \
        mobile/test/screens/navigation_screen_test.dart
git commit -m "feat(mobile): live turn instructions and ETA in NavigationScreen"
```

---

## Task 5: iOS integration smoke test + CI job

**Files:**
- Modify: `mobile/pubspec.yaml`
- Create: `mobile/integration_test/navigation_smoke_test.dart`
- Modify: `.github/workflows/ci-mobile.yml`

- [ ] **Step 1: Add `integration_test` to pubspec.yaml**

In `mobile/pubspec.yaml`, add to `dev_dependencies`:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  build_runner: ^2.4.13
  freezed: ^2.5.7
  json_serializable: ^6.9.0
  http_mock_adapter: ^0.6.1
  mocktail: ^1.0.4
```

- [ ] **Step 2: Run `flutter pub get`**

```bash
cd mobile && flutter pub get
```

Expected: Resolves without errors.

- [ ] **Step 3: Create smoke test**

Create `mobile/integration_test/navigation_smoke_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:beebeebike/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches and renders the map screen', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.byType(Scaffold), findsWidgets);
  });
}
```

- [ ] **Step 4: Add `test-mobile-ios` job to `ci-mobile.yml`**

Replace `.github/workflows/ci-mobile.yml` with:

```yaml
name: ci-mobile

on:
  push:
    paths:
      - 'mobile/**'
      - 'packages/ferrostar_flutter/**'
  pull_request:
    paths:
      - 'mobile/**'
      - 'packages/ferrostar_flutter/**'

jobs:
  test-mobile:
    name: Flutter tests (iOS)
    runs-on: macos-latest

    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.x'
          channel: 'stable'
          cache: true

      - name: Install dependencies (plugin)
        working-directory: packages/ferrostar_flutter
        run: flutter pub get

      - name: Install dependencies (app)
        working-directory: mobile
        run: flutter pub get

      - name: Analyze (app)
        working-directory: mobile
        run: flutter analyze

      - name: Test (app)
        working-directory: mobile
        run: flutter test

  test-mobile-ios:
    name: Flutter integration tests (iOS simulator)
    runs-on: macos-latest

    steps:
      - uses: actions/checkout@v4

      - uses: flutter-actions/setup-flutter@v3
        with:
          channel: stable

      - name: Install dependencies (plugin)
        working-directory: packages/ferrostar_flutter
        run: flutter pub get

      - name: Install dependencies (app)
        working-directory: mobile
        run: flutter pub get

      - name: Boot iPhone 17 simulator
        run: |
          UDID=$(xcrun simctl list devices available --json \
            | python3 -c "
          import json,sys
          devs = json.load(sys.stdin)['devices']
          for runtime, devices in devs.items():
            for d in devices:
              if 'iPhone 17' in d['name'] and d['isAvailable']:
                print(d['udid']); exit()
          ")
          xcrun simctl boot "$UDID"
          echo "SIM_UDID=$UDID" >> "$GITHUB_ENV"

      - name: Enable Flutter SPM integration
        working-directory: mobile
        run: flutter config --enable-swift-package-manager

      - name: Build (simulator, no codesign)
        working-directory: mobile
        run: flutter build ios --no-codesign --simulator

      - name: Run integration smoke test
        working-directory: mobile
        run: flutter test integration_test/navigation_smoke_test.dart -d "$SIM_UDID"
```

- [ ] **Step 5: Run unit tests one final time**

```bash
cd mobile && flutter test test/
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add mobile/pubspec.yaml \
        mobile/integration_test/navigation_smoke_test.dart \
        .github/workflows/ci-mobile.yml
git commit -m "feat(mobile): iOS simulator smoke test + ci-mobile integration job"
```
