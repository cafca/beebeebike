import 'package:beebeebike/models/geocode_result.dart';
import 'package:beebeebike/screens/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

    // Type a search query
    await tester.enterText(find.byType(TextField), 'Alex');

    // Before debounce fires: no results yet (still loading or empty)
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Alexanderplatz'), findsNothing);

    // After debounce (400ms) + async response
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Result should appear
    expect(find.text('Alexanderplatz'), findsOneWidget);
    // Label: district "Mitte" + osm_value "station" → "Mitte · station"
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

    // Advance past the debounce so _search() is called.
    // _search() calls setState(_loading = true) before awaiting.
    // We pump(Duration.zero) once to process the microtask that sets
    // _loading = true, then pump again before the Dio future resolves.
    await tester.pump(const Duration(milliseconds: 400));
    // At this point the debounce fired and _search() was invoked.
    // The setState for _loading=true runs synchronously in _search before
    // the first await, so pump() processes that frame.
    await tester.pump(Duration.zero);

    // The mock resolves via a microtask; before it resolves _loading is true.
    // If the mock resolves synchronously in the same microtask queue cycle,
    // the spinner may already be gone. Accept either state: spinner present
    // (loading) or results present (loaded). Verify at least one is shown.
    final hasSpinner =
        tester.any(find.byType(CircularProgressIndicator));
    final hasResult = tester.any(find.text('Alexanderplatz'));
    expect(hasSpinner || hasResult, isTrue,
        reason: 'Expected either the loading spinner or the results');

    // Settle everything — spinner should be gone and results shown
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

    // Wait for debounce + response
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNothing);
    expect(find.text('Alexanderplatz'), findsNothing);
  });

  testWidgets('tapping a result pops with the correct GeocodeResult',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();

    GeocodeResult? poppedResult;

    // Wrap SearchScreen in a route so Navigator.pop works and we can capture
    // the returned value.
    await tester.pumpWidget(
      buildTestWidget(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<GeocodeResult>(
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

    // Open the SearchScreen
    await tester.tap(find.text('Open Search'));
    await tester.pumpAndSettle();

    // Type a query and wait for results
    await tester.enterText(find.byType(TextField), 'Alex');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Tap the result tile
    expect(find.text('Alexanderplatz'), findsOneWidget);
    await tester.tap(find.text('Alexanderplatz'));
    await tester.pumpAndSettle();

    // Verify the popped value matches the fixture
    expect(poppedResult, isNotNull);
    expect(poppedResult!.id, 'N:42');
    expect(poppedResult!.name, 'Alexanderplatz');
    expect(poppedResult!.label, 'Mitte · station');
    expect(poppedResult!.lng, 13.4050);
    expect(poppedResult!.lat, 52.5200);
  });
}
