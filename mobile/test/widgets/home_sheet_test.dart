import 'dart:convert';

import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/models/location.dart';
import 'package:beebeebike/providers/route_provider.dart';
import 'package:beebeebike/widgets/home_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

Location _loc(String id, String name, double lat, double lng) => Location(
      id: id, name: name, label: 'via $id', lat: lat, lng: lng,
    );

Future<SharedPreferences> _prefsWithHistory(List<Location> history) async {
  SharedPreferences.setMockInitialValues({
    'beebeebike.recentSearches':
        history.map((e) => jsonEncode(e.toJson())).toList(),
  });
  return SharedPreferences.getInstance();
}

Widget _host({
  required SharedPreferences prefs,
  required DraggableScrollableController controller,
  Location? homeLocation,
  bool authenticated = true,
  ProviderContainer? container,
}) {
  final widget = Scaffold(
    body: HomeSheet(
      onNavigateHome: () {},
      sheetController: controller,
    ),
  );
  final app = MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: widget,
  );
  if (container != null) {
    return UncontrolledProviderScope(container: container, child: app);
  }
  return ProviderScope(
    overrides: testProviderOverrides(
      prefs: prefs,
      authenticated: authenticated,
      homeLocation: homeLocation,
    ),
    child: app,
  );
}

void main() {
  testWidgets('RECENT section hidden when search history empty',
      (tester) async {
    final prefs = await _prefsWithHistory(const []);
    final controller = DraggableScrollableController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(prefs: prefs, controller: controller));
    await tester.pump();

    expect(find.text('RECENT'), findsNothing);
  });

  testWidgets('RECENT section shows up to 3 items when history populated',
      (tester) async {
    final prefs = await _prefsWithHistory([
      _loc('a', 'Alexanderplatz', 52.52, 13.405),
      _loc('b', 'Brandenburger Tor', 52.516, 13.377),
      _loc('c', 'Checkpoint Charlie', 52.507, 13.39),
      _loc('d', 'Dom', 52.519, 13.401),
    ]);
    final controller = DraggableScrollableController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(prefs: prefs, controller: controller));
    await tester.pump();

    expect(find.text('RECENT'), findsOneWidget);
    expect(find.text('Alexanderplatz'), findsOneWidget);
    expect(find.text('Brandenburger Tor'), findsOneWidget);
    expect(find.text('Checkpoint Charlie'), findsOneWidget);
    // 4th item must be clipped.
    expect(find.text('Dom'), findsNothing);
  });

  testWidgets('tapping a recent item sets destination', (tester) async {
    final prefs = await _prefsWithHistory([
      _loc('a', 'Alexanderplatz', 52.52, 13.405),
    ]);
    final controller = DraggableScrollableController();
    addTearDown(controller.dispose);

    final container = ProviderContainer(
      overrides: testProviderOverrides(prefs: prefs),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_host(
      prefs: prefs,
      controller: controller,
      container: container,
    ));
    await tester.pump();

    // Pre-seed origin so the tap handler skips the Geolocator GPS branch,
    // which has no platform channel in the test env.
    container.read(routeControllerProvider.notifier).setOrigin(fakeOrigin());

    expect(container.read(routeControllerProvider).destination, isNull);

    // Expand the sheet so the recent row is inside the hit-test viewport.
    controller.jumpTo(0.46);
    await tester.pump();

    await tester.tap(find.text('Alexanderplatz'));
    await tester.pump();

    expect(
      container.read(routeControllerProvider).destination?.id,
      'a',
    );

    // Drain the pending /api/route preview fetch that setDestination fired so
    // the framework doesn't see a pending Timer at teardown.
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });

  testWidgets('Go home button disabled when no home saved', (tester) async {
    final prefs = await _prefsWithHistory(const []);
    final controller = DraggableScrollableController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(prefs: prefs, controller: controller));
    await tester.pump();

    expect(find.text('Go home'), findsOneWidget);
    // Without a saved home there is no ETA subtitle.
    expect(find.textContaining('min'), findsNothing);
    expect(find.text('Calculating ETA…'), findsNothing);
  });

  testWidgets('Log in button shown when not authenticated', (tester) async {
    final prefs = await _prefsWithHistory(const []);
    final controller = DraggableScrollableController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(
      prefs: prefs,
      controller: controller,
      authenticated: false,
    ));
    await tester.pump();

    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Go home'), findsNothing);
  });

  testWidgets('Go home button shows calculating ETA subtitle when home saved',
      (tester) async {
    final prefs = await _prefsWithHistory(const []);
    final controller = DraggableScrollableController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(
      prefs: prefs,
      controller: controller,
      homeLocation: fakeHome(),
    ));
    await tester.pump();

    expect(find.text('Go home'), findsOneWidget);
    expect(find.text('Calculating ETA…'), findsOneWidget);
  });
}
