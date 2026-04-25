import 'dart:async';

import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/models/location.dart';
import 'package:beebeebike/providers/route_provider.dart';
import 'package:beebeebike/widgets/route_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

MaterialApp _localizedApp(Widget child) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows current location and where-to hint when no route state',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      buildTestWidget(
        const Scaffold(body: RouteCard()),
        prefs: prefs,
      ),
    );

    expect(find.text('Current location'), findsOneWidget);
    expect(find.text('Where to?'), findsOneWidget);
  });

  testWidgets('shows custom origin name when non-GPS origin set',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: testProviderOverrides(prefs: prefs),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _localizedApp(const Scaffold(body: RouteCard())),
      ),
    );

    unawaited(container.read(routeControllerProvider.notifier).setOrigin(
          const Location(
            id: 'N:1',
            name: 'Brandenburger Tor',
            label: 'Mitte, Berlin',
            lng: 13.3777,
            lat: 52.5163,
          ),
        ));
    await tester.pump();

    expect(find.text('Brandenburger Tor'), findsOneWidget);
    expect(find.text('Current location'), findsNothing);
  });

  testWidgets('shows current location when origin has id gps', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: testProviderOverrides(prefs: prefs),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _localizedApp(const Scaffold(body: RouteCard())),
      ),
    );

    unawaited(container.read(routeControllerProvider.notifier).setOrigin(
          const Location(
            id: 'gps',
            name: 'Current location',
            label: 'Current location',
            lng: 13.4533,
            lat: 52.5065,
          ),
        ));
    await tester.pump();

    expect(find.text('Current location'), findsOneWidget);
    expect(find.text('Where to?'), findsOneWidget);
  });

  testWidgets('shows destination name when destination set', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: testProviderOverrides(prefs: prefs),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _localizedApp(const Scaffold(body: RouteCard())),
      ),
    );

    unawaited(container.read(routeControllerProvider.notifier).setDestination(
          const Location(
            id: 'N:42',
            name: 'Alexanderplatz',
            label: 'Mitte · station',
            lng: 13.4050,
            lat: 52.5200,
          ),
        ));
    await tester.pump();

    expect(find.text('Alexanderplatz'), findsOneWidget);
    expect(find.text('Where to?'), findsNothing);
  });

  testWidgets('shows person icon on origin row and swap icon on destination row',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      buildTestWidget(const Scaffold(body: RouteCard()), prefs: prefs),
    );

    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.byIcon(Icons.swap_vert), findsOneWidget);
  });

  testWidgets('swap button is disabled when no destination', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      buildTestWidget(const Scaffold(body: RouteCard()), prefs: prefs),
    );

    final swapButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.swap_vert),
    );
    expect(swapButton.onPressed, isNull);
  });

  testWidgets('swap button is enabled when destination is set', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: testProviderOverrides(prefs: prefs),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _localizedApp(const Scaffold(body: RouteCard())),
      ),
    );

    unawaited(container.read(routeControllerProvider.notifier).setDestination(
          fakeDest(),
        ));
    await tester.pump();

    final swapButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.swap_vert),
    );
    expect(swapButton.onPressed, isNotNull);
  });

  test('setDestination with null origin does not trigger route preview', () {
    // Regression: _openDestinationSearch must set GPS origin before calling
    // setDestination, otherwise _maybeLoadPreview returns early (origin==null)
    // and no route is computed.
    //
    // This unit test verifies the provider contract: calling setDestination
    // with no origin leaves preview null and isLoading false.
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(overrides: []);
    addTearDown(container.dispose);

    // No origin set — destination alone must not compute a route
    unawaited(container.read(routeControllerProvider.notifier).setDestination(
          const Location(
            id: 'N:42',
            name: 'Alexanderplatz',
            label: 'Mitte · station',
            lng: 13.4050,
            lat: 52.5200,
          ),
        ));

    final state = container.read(routeControllerProvider);
    expect(state.origin, isNull);
    expect(state.preview, isNull);
    expect(state.isLoading, isFalse);
  });

  test('setOrigin then setDestination triggers route preview load', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: testProviderOverrides(prefs: prefs),
    );
    addTearDown(container.dispose);

    await container.read(routeControllerProvider.notifier).setOrigin(
          fakeOrigin(),
        );
    // After setting origin only: no preview yet
    expect(container.read(routeControllerProvider).preview, isNull);

    await container.read(routeControllerProvider.notifier).setDestination(
          fakeDest(),
        );
    // After setting destination: preview should be loaded
    final state = container.read(routeControllerProvider);
    expect(state.preview, isNotNull);
    expect(state.isLoading, isFalse);
  });
}
