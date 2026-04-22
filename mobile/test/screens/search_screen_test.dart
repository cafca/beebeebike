import 'package:beebeebike/models/location.dart';
import 'package:beebeebike/screens/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('always shows current location tile at top', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      buildTestWidget(
        const SearchScreen(),
        prefs: prefs,
      ),
    );

    expect(find.text('Current location'), findsOneWidget);
    expect(find.byIcon(Icons.my_location), findsOneWidget);
  });

  testWidgets('tapping current location pops with gps Location', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    Location? poppedResult;

    await tester.pumpWidget(
      buildTestWidget(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<Location>(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
              poppedResult = result;
            },
            child: const Text('Open Search'),
          ),
        ),
        prefs: prefs,
      ),
    );

    await tester.tap(find.text('Open Search'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Current location'));
    await tester.pumpAndSettle();

    expect(poppedResult, isNotNull);
    expect(poppedResult!.id, 'gps');
    expect(poppedResult!.name, 'Current location');
  });

  testWidgets('shows home location tile when homeLocation provided',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    const home = Location(
      id: 'home',
      name: 'Zuhause',
      label: 'Meine Straße 1, Neukölln',
      lng: 13.4333,
      lat: 52.4833,
    );
    await tester.pumpWidget(
      buildTestWidget(
        const SearchScreen(),
        prefs: prefs,
        homeLocation: home,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Meine Straße 1, Neukölln'), findsOneWidget);
  });

  testWidgets('tapping home location pops with home Location', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    const home = Location(
      id: 'home',
      name: 'Zuhause',
      label: 'Meine Straße 1, Neukölln',
      lng: 13.4333,
      lat: 52.4833,
    );
    Location? poppedResult;

    await tester.pumpWidget(
      buildTestWidget(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<Location>(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
              poppedResult = result;
            },
            child: const Text('Open Search'),
          ),
        ),
        prefs: prefs,
        homeLocation: home,
      ),
    );

    await tester.tap(find.text('Open Search'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(poppedResult, isNotNull);
    expect(poppedResult!.id, 'home');
    expect(poppedResult!.lng, 13.4333);
    expect(poppedResult!.lat, 52.4833);
  });

  testWidgets('shows history items when no query typed', (tester) async {
    SharedPreferences.setMockInitialValues({
      'beebeebike.recentSearches': [
        '{"id":"N:99","name":"Checkpoint Charlie","label":"Mitte","lng":13.3903,"lat":52.5075}',
      ],
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      buildTestWidget(
        const SearchScreen(),
        prefs: prefs,
      ),
    );

    expect(find.text('Checkpoint Charlie'), findsOneWidget);
    expect(find.byIcon(Icons.history), findsOneWidget);
  });

  testWidgets('hides history and shows results when query typed',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'beebeebike.recentSearches': [
        '{"id":"N:99","name":"Checkpoint Charlie","label":"Mitte","lng":13.3903,"lat":52.5075}',
      ],
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      buildTestWidget(
        const SearchScreen(),
        prefs: prefs,
        geocodeReturnsResults: true,
      ),
    );

    await tester.enterText(find.byType(TextField), 'Alex');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Checkpoint Charlie'), findsNothing);
    expect(find.text('Alexanderplatz'), findsOneWidget);
  });

  testWidgets('shows search results after typing with debounce',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      buildTestWidget(
        const SearchScreen(),
        prefs: prefs,
        geocodeReturnsResults: true,
      ),
    );

    await tester.enterText(find.byType(TextField), 'Alex');

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Alexanderplatz'), findsNothing);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Alexanderplatz'), findsOneWidget);
    expect(find.text('Mitte · station'), findsOneWidget);
  });

  testWidgets('shows CircularProgressIndicator while loading', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      buildTestWidget(
        const SearchScreen(),
        prefs: prefs,
        geocodeReturnsResults: true,
      ),
    );

    await tester.enterText(find.byType(TextField), 'Alex');

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(Duration.zero);

    final hasSpinner = tester.any(find.byType(CircularProgressIndicator));
    final hasResult = tester.any(find.text('Alexanderplatz'));
    expect(hasSpinner || hasResult, isTrue,
        reason: 'Expected either the loading spinner or the results');

    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Alexanderplatz'), findsOneWidget);
  });

  testWidgets('shows empty list when geocode returns no results',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      buildTestWidget(
        const SearchScreen(),
        prefs: prefs,
        geocodeReturnsResults: false,
      ),
    );

    await tester.enterText(find.byType(TextField), 'nowhere');

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Alexanderplatz'), findsNothing);
  });

  testWidgets('tapping a result pops with the correct Location',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();

    Location? poppedResult;

    await tester.pumpWidget(
      buildTestWidget(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<Location>(
                MaterialPageRoute(
                  builder: (_) => const SearchScreen(),
                ),
              );
              poppedResult = result;
            },
            child: const Text('Open Search'),
          ),
        ),
        prefs: prefs,
        geocodeReturnsResults: true,
      ),
    );

    await tester.tap(find.text('Open Search'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Alex');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Alexanderplatz'), findsOneWidget);
    await tester.tap(find.text('Alexanderplatz'));
    await tester.pumpAndSettle();

    expect(poppedResult, isNotNull);
    expect(poppedResult!.id, 'N:42');
    expect(poppedResult!.name, 'Alexanderplatz');
    expect(poppedResult!.label, 'Mitte · station');
    expect(poppedResult!.lng, 13.4050);
    expect(poppedResult!.lat, 52.5200);
  });
}
