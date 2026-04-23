import 'dart:async';

import 'package:beebeebike/app.dart';
import 'package:beebeebike/config/app_config.dart';
import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/navigation/camera_controller.dart';
import 'package:beebeebike/navigation/navigation_service.dart';
import 'package:beebeebike/providers/navigation_camera_provider.dart';
import 'package:beebeebike/providers/navigation_provider.dart';
import 'package:beebeebike/providers/navigation_session_provider.dart';
import 'package:beebeebike/screens/map_screen.dart';
import 'package:beebeebike/services/map_style_loader.dart';
import 'package:beebeebike/widgets/arrived_sheet.dart';
import 'package:beebeebike/widgets/recenter_fab.dart';
import 'package:beebeebike/widgets/rerouting_toast.dart';
import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

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

class _NavHarness {
  _NavHarness({
    required this.tester,
    required this.navStream,
    required this.cam,
    required this.rerouteStream,
  });

  final WidgetTester tester;
  final StreamController<NavigationState> navStream;
  final NavigationCameraController cam;
  final StreamController<bool> rerouteStream;
}

Future<_NavHarness> _pumpNavActive(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final navStream = StreamController<NavigationState>.broadcast();
  final rerouteStream = StreamController<bool>.broadcast();
  final cam = NavigationCameraController();

  final fakeService = NavigationService(
    createController: (_, __) => throw UnimplementedError(),
    loadNavigationRoute: ({required origin, required destination}) =>
        throw UnimplementedError(),
    locationStreamFactory: () => const Stream.empty(),
    speakInstruction: (_) async {},
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...testProviderOverrides(prefs: prefs),
        appConfigProvider.overrideWithValue(
          const AppConfig(
            apiBaseUrl: 'http://localhost',
            tileServerBaseUrl: 'http://localhost',
            tileStyleUrl: 'http://localhost/tiles',
            ratingsSseEnabled: false,
          ),
        ),
        mapStyleProvider.overrideWith((ref) => Future.value('{}')),
        navigationSessionProvider.overrideWith((ref) => true),
        navigationStateProvider.overrideWith((ref) => navStream.stream),
        rerouteInProgressProvider
            .overrideWith((ref) => rerouteStream.stream),
        navigationServiceProvider.overrideWithValue(fakeService),
        navigationCameraControllerProvider.overrideWith((ref) => cam),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MapScreen(),
      ),
    ),
  );
  await tester.pump();
  addTearDown(navStream.close);
  addTearDown(rerouteStream.close);
  return _NavHarness(
    tester: tester,
    navStream: navStream,
    cam: cam,
    rerouteStream: rerouteStream,
  );
}

Future<void> _triggerRebuild(
    WidgetTester tester, StreamController<NavigationState> stream) async {
  stream.add(_baseState());
  await tester.pump();
}

void main() {
  testWidgets('recenter FAB hidden initially', (tester) async {
    await _pumpNavActive(tester);
    expect(find.byType(RecenterFab), findsNothing);
  });

  testWidgets('recenter FAB visible when camera enters free mode',
      (tester) async {
    final h = await _pumpNavActive(tester);
    h.cam.onFirstFix();
    h.cam.onTrackingDismissed();
    await _triggerRebuild(tester, h.navStream);
    expect(find.byType(RecenterFab), findsOneWidget);
  });

  testWidgets(
      'rerouting toast follows rerouteInProgress stream (shown when true, hidden when false)',
      (tester) async {
    final h = await _pumpNavActive(tester);
    h.rerouteStream.add(true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ReroutingToast), findsOneWidget);

    h.rerouteStream.add(false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ReroutingToast), findsNothing);
  });

  testWidgets('arrived sheet replaces ETA sheet on TripStatus.complete',
      (tester) async {
    final h = await _pumpNavActive(tester);
    h.navStream.add(_baseState(status: TripStatus.complete));
    await tester.pump();
    await tester.pump();
    expect(find.byType(ArrivedSheet), findsOneWidget);
  });

  testWidgets('rerouting toast clears when arrival fires while rerouting',
      (tester) async {
    final h = await _pumpNavActive(tester);
    h.rerouteStream.add(true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ReroutingToast), findsOneWidget);

    h.navStream.add(_baseState(status: TripStatus.complete));
    await tester.pump();
    await tester.pump();
    expect(find.byType(ArrivedSheet), findsOneWidget);
    expect(find.byType(ReroutingToast), findsNothing);
  });
}
