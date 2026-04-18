import 'package:beebeebike/models/route_state.dart';
import 'package:beebeebike/providers/route_provider.dart';
import 'package:beebeebike/screens/map_screen.dart';
import 'package:beebeebike/screens/navigation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

// --- Stub controllers ---

class _LoadingRouteController extends RouteController {
  @override
  RouteState build() => const RouteState(isLoading: true);
}

class _ErrorRouteController extends RouteController {
  @override
  RouteState build() => const RouteState(error: 'some error');
}

class _PreviewRouteController extends RouteController {
  @override
  RouteState build() => RouteState(preview: fakePreview());
}

// --- Tests ---

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('loading state shows CircularProgressIndicator', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testProviderOverrides(prefs: prefs),
          routeControllerProvider.overrideWith(_LoadingRouteController.new),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error state shows "Could not load route"', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testProviderOverrides(prefs: prefs),
          routeControllerProvider.overrideWith(_ErrorRouteController.new),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Could not load route'), findsOneWidget);
  });

  testWidgets('preview state shows Start button and route info', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testProviderOverrides(prefs: prefs),
          routeControllerProvider.overrideWith(_PreviewRouteController.new),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );
    await tester.pump();

    // RouteSummary shows a Start button
    expect(find.text('Start'), findsOneWidget);

    // time=1200s → 20 min, distance=5000m → 5.0 km
    expect(find.textContaining('20 min'), findsOneWidget);
    expect(find.textContaining('5.0 km'), findsOneWidget);
  });

  testWidgets('tapping Start navigates to NavigationScreen', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testProviderOverrides(prefs: prefs),
          routeControllerProvider.overrideWith(_PreviewRouteController.new),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Start'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationScreen), findsOneWidget);
  });

  testWidgets('empty state shows Home and Saved places placeholders',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      buildTestWidget(const MapScreen(), prefs: prefs),
    );
    await tester.pump();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Saved places'), findsOneWidget);
  });
}
