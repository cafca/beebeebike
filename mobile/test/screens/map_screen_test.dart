import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/models/route_state.dart';
import 'package:beebeebike/providers/navigation_session_provider.dart';
import 'package:beebeebike/providers/route_provider.dart';
import 'package:beebeebike/screens/map_screen.dart';
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
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MapScreen(),
        ),
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
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MapScreen(),
        ),
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
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MapScreen(),
        ),
      ),
    );
    await tester.pump();

    // RouteSummary shows a Start button
    expect(find.text('Start ride'), findsOneWidget);

    // time=1200s → 20 min, distance=5000m → 5.0 km
    expect(find.textContaining('20 min'), findsOneWidget);
    expect(find.textContaining('5.0 km'), findsOneWidget);
  });

  testWidgets('tapping Start flips navigationSessionProvider to true',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      ...testProviderOverrides(prefs: prefs),
      routeControllerProvider.overrideWith(_PreviewRouteController.new),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MapScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(container.read(navigationSessionProvider), isFalse);
    expect(find.text('Start ride'), findsOneWidget);
    await tester.tap(find.text('Start ride'));
    await tester.pump();

    expect(container.read(navigationSessionProvider), isTrue);
  });

  testWidgets('empty state shows Set home CTA when logged in but no home saved',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      buildTestWidget(const MapScreen(), prefs: prefs, authenticated: true),
    );
    await tester.pump();

    // Without a saved home the sheet shows the Set home CTA, not a disabled
    // Go home button.
    expect(find.text('Set home'), findsOneWidget);
    expect(find.text('Go home'), findsNothing);
  });

  testWidgets('Go home subtitle shows calculating state while ETA resolves',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      buildTestWidget(
        const MapScreen(),
        prefs: prefs,
        authenticated: true,
        homeLocation: fakeHome(),
      ),
    );
    await tester.pump();

    expect(find.text('Go home'), findsOneWidget);
    expect(find.text('Calculating ETA…'), findsOneWidget);
  });

  testWidgets('landing CTA shows Log in when not authenticated',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      buildTestWidget(const MapScreen(), prefs: prefs),
    );
    await tester.pump();

    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Go home'), findsNothing);
  });
}
