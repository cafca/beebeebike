import 'dart:async';

import 'package:beebeebike/app.dart';
import 'package:beebeebike/config/app_config.dart';
import 'package:beebeebike/models/location.dart';
import 'package:beebeebike/navigation/camera_controller.dart';
import 'package:beebeebike/navigation/navigation_service.dart';
import 'package:beebeebike/providers/navigation_camera_provider.dart';
import 'package:beebeebike/providers/navigation_provider.dart';
import 'package:beebeebike/providers/route_provider.dart';
import 'package:beebeebike/screens/navigation_screen.dart';
import 'package:beebeebike/services/map_style_loader.dart';
import 'package:beebeebike/widgets/arrived_sheet.dart';
import 'package:beebeebike/widgets/recenter_fab.dart';
import 'package:beebeebike/widgets/rerouting_toast.dart';
import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

NavigationState _baseState({
  TripStatus status = TripStatus.navigating,
  bool isOffRoute = false,
  UserLocation? snapped,
}) {
  return NavigationState(
    status: status,
    isOffRoute: isOffRoute,
    snappedLocation: snapped,
    progress: const TripProgress(
      distanceToNextManeuverM: 150,
      distanceRemainingM: 3200,
      durationRemainingMs: 720000,
    ),
  );
}

Future<(WidgetTester, StreamController<NavigationState>,
        NavigationCameraController)>
    _pump(WidgetTester tester) async {
  final navStream = StreamController<NavigationState>.broadcast();
  final cam = NavigationCameraController();

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
        appConfigProvider.overrideWithValue(
          const AppConfig(
            apiBaseUrl: 'http://localhost',
            tileServerBaseUrl: 'http://localhost',
            tileStyleUrl: 'http://localhost/tiles',
          ),
        ),
        mapStyleProvider.overrideWith((ref) => Future.value('{}')),
        navigationStateProvider
            .overrideWith((ref) => navStream.stream),
        navigationServiceProvider.overrideWithValue(fakeService),
        navigationCameraControllerProvider.overrideWith((ref) => cam),
        routeControllerProvider.overrideWith(() {
          return _SeededRouteController(
            origin: const Location(
                id: 'o', name: 'o', label: 'o', lng: 13.4, lat: 52.5),
            destination: const Location(
                id: 'd', name: 'd', label: 'd', lng: 13.5, lat: 52.55),
          );
        }),
      ],
      child: const MaterialApp(home: NavigationScreen()),
    ),
  );
  await tester.pump();
  addTearDown(navStream.close);
  return (tester, navStream, cam);
}

/// Forces a widget rebuild by emitting a neutral nav-state event.
/// The screen's ref.listen callback calls setState(), which rebuilds the
/// widget tree so the new cam.mode value is picked up from the build method.
Future<void> _triggerRebuild(
    WidgetTester tester, StreamController<NavigationState> stream) async {
  stream.add(_baseState());
  await tester.pump();
}

void main() {
  testWidgets('recenter FAB hidden initially', (tester) async {
    await _pump(tester);
    expect(find.byType(RecenterFab), findsNothing);
  });

  testWidgets('recenter FAB visible when camera enters free mode',
      (tester) async {
    final (_, stream, cam) = await _pump(tester);
    // Mutate the cam controller (ChangeNotifier) then force a rebuild via
    // a nav-state event so the screen's build() re-evaluates cam.mode.
    cam.onFirstFix();
    cam.onTrackingDismissed();
    await _triggerRebuild(tester, stream);
    expect(find.byType(RecenterFab), findsOneWidget);
  });

  testWidgets('rerouting toast appears when isOffRoute flips true',
      (tester) async {
    final (_, stream, __) = await _pump(tester);
    stream.add(_baseState(isOffRoute: true));
    // Use pump(duration) rather than pumpAndSettle because ReroutingToast
    // contains a CircularProgressIndicator that never stops animating.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ReroutingToast), findsOneWidget);

    stream.add(_baseState(isOffRoute: false));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ReroutingToast), findsNothing);
  });

  testWidgets('arrived sheet replaces ETA sheet on TripStatus.complete',
      (tester) async {
    final (_, stream, cam) = await _pump(tester);
    // _handleArrival() returns early in tests (no MapLibre map controller),
    // so call cam.onArrived() directly, then force a rebuild via the nav stream.
    cam.onArrived();
    await _triggerRebuild(tester, stream);
    expect(find.byType(ArrivedSheet), findsOneWidget);
  });
}

class _SeededRouteController extends RouteController {
  _SeededRouteController({required this.origin, required this.destination});
  final Location origin;
  final Location destination;
  @override
  build() => super.build().copyWith(origin: origin, destination: destination);
}
