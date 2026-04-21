import 'package:beebeebike/models/location.dart';
import 'package:beebeebike/providers/route_provider.dart';
import 'package:beebeebike/widgets/route_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows Mein Standort and Wohin? when no route state',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      buildTestWidget(
        const Scaffold(body: RouteCard()),
        prefs: prefs,
      ),
    );

    expect(find.text('Mein Standort'), findsOneWidget);
    expect(find.text('Wohin?'), findsOneWidget);
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
        child: const MaterialApp(
          home: Scaffold(body: RouteCard()),
        ),
      ),
    );

    container.read(routeControllerProvider.notifier).setOrigin(
          const Location(
            id: 'N:1',
            name: 'Brandenburger Tor',
            label: 'Mitte, Berlin',
            lng: 13.3777,
            lat: 52.5163,
          ),
        );
    await tester.pump();

    expect(find.text('Brandenburger Tor'), findsOneWidget);
    expect(find.text('Mein Standort'), findsNothing);
  });

  testWidgets('shows Mein Standort when origin has id gps', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: testProviderOverrides(prefs: prefs),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: RouteCard()),
        ),
      ),
    );

    container.read(routeControllerProvider.notifier).setOrigin(
          const Location(
            id: 'gps',
            name: 'Mein Standort',
            label: 'Mein Standort',
            lng: 13.4533,
            lat: 52.5065,
          ),
        );
    await tester.pump();

    expect(find.text('Mein Standort'), findsOneWidget);
    expect(find.text('Wohin?'), findsOneWidget);
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
        child: const MaterialApp(
          home: Scaffold(body: RouteCard()),
        ),
      ),
    );

    container.read(routeControllerProvider.notifier).setDestination(
          const Location(
            id: 'N:42',
            name: 'Alexanderplatz',
            label: 'Mitte · station',
            lng: 13.4050,
            lat: 52.5200,
          ),
        );
    await tester.pump();

    expect(find.text('Alexanderplatz'), findsOneWidget);
    expect(find.text('Wohin?'), findsNothing);
  });
}
