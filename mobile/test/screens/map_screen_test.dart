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
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MapScreen(),
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
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MapScreen(),
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
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MapScreen(),
        ),
      ),
    );
    await tester.pump();

    // RouteSummary shows a Start button
    expect(find.text('Start'), findsOneWidget);

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
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MapScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(container.read(navigationSessionProvider), isFalse);
    expect(find.text('Start'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pump();

    expect(container.read(navigationSessionProvider), isTrue);
  });

  testWidgets('empty state shows drag handle', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      buildTestWidget(const MapScreen(), prefs: prefs),
    );
    await tester.pump();

    // No route, no home saved — just the drag handle container, no chips
    expect(find.text('Saved places'), findsNothing);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('empty state shows Home chip when home is saved', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      buildTestWidget(const MapScreen(), prefs: prefs, homeLocation: fakeHome()),
    );
    await tester.pump();

    expect(find.text('Home'), findsOneWidget);
  });
}
