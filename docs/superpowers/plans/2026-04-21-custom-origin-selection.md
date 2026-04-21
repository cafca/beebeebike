# Custom Origin Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Google Maps-style route card with editable origin/destination fields, where origin defaults to "Mein Standort" (GPS) but can be changed via search, and the search screen always shows "Mein Standort" + recent history + results.

**Architecture:** Replace the single-field `BeeBeeBikeSearchBar` with a two-field `RouteCard` widget that reads from `routeControllerProvider` and opens `SearchScreen` for each field. `SearchScreen` gains a static "Mein Standort" row, history section (from `searchHistoryProvider`), and changes its return type from `GeocodeResult?` to `Location?`. All GPS resolution stays in the UI layer (same pattern as existing code).

**Tech Stack:** Flutter/Dart, Riverpod (`ConsumerWidget`), Geolocator, `routeControllerProvider` (`NotifierProvider<RouteController, RouteState>`), `searchHistoryProvider` (`NotifierProvider<SearchHistoryController, List<Location>>`).

---

## File Structure

| File | Change | Responsibility |
|------|--------|----------------|
| `mobile/lib/screens/search_screen.dart` | Modify | Add "Mein Standort" row + history section; return `Location?` |
| `mobile/lib/widgets/route_card.dart` | **Create** | Two-field card; opens SearchScreen; GPS resolution; history save |
| `mobile/lib/screens/map_screen.dart` | Modify | Replace `BeeBeeBikeSearchBar` with `RouteCard`; update label strings |
| `mobile/test/screens/search_screen_test.dart` | Modify | Update return type refs; add tests for new sections |
| `mobile/test/widgets/route_card_test.dart` | **Create** | Widget tests for label display based on route state |

---

## Task 1: Update SearchScreen — return `Location?`, add "Mein Standort" + history

**Files:**
- Modify: `mobile/lib/screens/search_screen.dart`
- Modify: `mobile/test/screens/search_screen_test.dart`

- [ ] **Step 1.1: Add failing tests for new SearchScreen behaviour**

Add these tests to `mobile/test/screens/search_screen_test.dart` BEFORE the existing tests (they will fail until Step 1.3):

```dart
// Add import at top:
import 'package:beebeebike/models/location.dart';

// Add these test cases inside main():

testWidgets('always shows Mein Standort tile at top', (tester) async {
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    buildTestWidget(
      const SearchScreen(),
      prefs: prefs,
    ),
  );

  expect(find.text('Mein Standort'), findsOneWidget);
  expect(find.byIcon(Icons.my_location), findsOneWidget);
});

testWidgets('tapping Mein Standort pops with gps Location', (tester) async {
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

  await tester.tap(find.text('Mein Standort'));
  await tester.pumpAndSettle();

  expect(poppedResult, isNotNull);
  expect(poppedResult!.id, 'gps');
  expect(poppedResult!.name, 'Mein Standort');
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

  // History visible when no query
  expect(find.text('Checkpoint Charlie'), findsOneWidget);
  expect(find.byIcon(Icons.history), findsOneWidget);
});

testWidgets('hides history and shows results when query typed', (tester) async {
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
```

Also update the existing `'tapping a result pops with the correct GeocodeResult'` test:
- Change `push<GeocodeResult>` → `push<Location>`
- Change `GeocodeResult? poppedResult` → `Location? poppedResult`
- Remove the `import 'package:beebeebike/models/geocode_result.dart';` from test file and replace with `location.dart` import

- [ ] **Step 1.2: Run tests to verify they fail**

```bash
cd /Users/pv/code/beebeebike/.claude/worktrees/suspicious-brattain-efe4cf
just test-mobile 2>&1 | tail -50
```

Expected: Compilation errors (type mismatch `GeocodeResult` vs `Location`) and test failures for the new tests.

- [ ] **Step 1.3: Rewrite search_screen.dart**

Replace the entire contents of `mobile/lib/screens/search_screen.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../api/geocode_api.dart';
import '../models/geocode_result.dart';
import '../models/location.dart';
import '../providers/search_history_provider.dart';

final _geocodeApiProvider =
    Provider<GeocodeApi>((ref) => GeocodeApi(ref.watch(dioProvider)));

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final List<GeocodeResult> _results = [];
  Timer? _debounce;
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _results.clear());
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _search(value.trim()),
    );
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final results = await ref.read(_geocodeApiProvider).search(query);
      if (mounted) setState(() => _results..clear()..addAll(results));
    } catch (_) {
      if (mounted) setState(() => _results.clear());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectLocation(Location location) {
    Navigator.of(context).pop(location);
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(searchHistoryProvider);
    final hasQuery = _controller.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Suche...',
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
          onSubmitted: (value) {
            _debounce?.cancel();
            if (value.trim().isNotEmpty) _search(value.trim());
          },
        ),
      ),
      body: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.my_location),
            title: const Text('Mein Standort'),
            onTap: () => _selectLocation(const Location(
              id: 'gps',
              name: 'Mein Standort',
              label: 'Mein Standort',
              lng: 0,
              lat: 0,
            )),
          ),
          const Divider(height: 1),
          Expanded(
            child: hasQuery
                ? _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final r = _results[index];
                          return ListTile(
                            leading: const Icon(Icons.place_outlined),
                            title: Text(r.name),
                            subtitle:
                                r.label.isNotEmpty ? Text(r.label) : null,
                            onTap: () => _selectLocation(Location(
                              id: r.id,
                              name: r.name,
                              label: r.label,
                              lng: r.lng,
                              lat: r.lat,
                            )),
                          );
                        },
                      )
                : ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final h = history[index];
                      return ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(h.name),
                        subtitle: h.label.isNotEmpty ? Text(h.label) : null,
                        onTap: () => _selectLocation(h),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 1.4: Update search_screen_test.dart**

The full updated file `mobile/test/screens/search_screen_test.dart`:

```dart
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

  testWidgets('always shows Mein Standort tile at top', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      buildTestWidget(
        const SearchScreen(),
        prefs: prefs,
      ),
    );

    expect(find.text('Mein Standort'), findsOneWidget);
    expect(find.byIcon(Icons.my_location), findsOneWidget);
  });

  testWidgets('tapping Mein Standort pops with gps Location', (tester) async {
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

    await tester.tap(find.text('Mein Standort'));
    await tester.pumpAndSettle();

    expect(poppedResult, isNotNull);
    expect(poppedResult!.id, 'gps');
    expect(poppedResult!.name, 'Mein Standort');
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

    // No search result tiles (Mein Standort tile is present but no ListTile
    // from results since Mein Standort uses ListTile too - check by text)
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
```

- [ ] **Step 1.5: Run tests — expect pass**

```bash
cd /Users/pv/code/beebeebike/.claude/worktrees/suspicious-brattain-efe4cf
just test-mobile 2>&1 | tail -50
```

Expected: All search_screen tests pass. `map_screen.dart` will have a compile error (still uses `push<GeocodeResult>` with old SearchScreen) — this is fine, will fix in Task 3.

- [ ] **Step 1.6: Commit**

```bash
cd /Users/pv/code/beebeebike/.claude/worktrees/suspicious-brattain-efe4cf
git add mobile/lib/screens/search_screen.dart mobile/test/screens/search_screen_test.dart
git commit -m "feat(mobile): SearchScreen returns Location?, adds Mein Standort + history"
```

---

## Task 2: Create RouteCard widget

**Files:**
- Create: `mobile/lib/widgets/route_card.dart`
- Create: `mobile/test/widgets/route_card_test.dart`

- [ ] **Step 2.1: Write failing widget tests**

Create `mobile/test/widgets/route_card_test.dart`:

```dart
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
```

- [ ] **Step 2.2: Run tests to verify they fail**

```bash
cd /Users/pv/code/beebeebike/.claude/worktrees/suspicious-brattain-efe4cf
cd mobile && flutter test test/widgets/route_card_test.dart 2>&1 | tail -20
```

Expected: `Error: 'RouteCard' isn't defined` — the file doesn't exist yet.

- [ ] **Step 2.3: Create route_card.dart**

Create `mobile/lib/widgets/route_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/location.dart';
import '../providers/route_provider.dart';
import '../providers/search_history_provider.dart';
import '../screens/search_screen.dart';

class RouteCard extends ConsumerWidget {
  const RouteCard({super.key});

  Future<Location> _resolveGps() async {
    try {
      final pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition();
      return Location(
        id: 'gps',
        name: 'Mein Standort',
        label: 'Mein Standort',
        lng: pos.longitude,
        lat: pos.latitude,
      );
    } catch (_) {
      return const Location(
        id: 'gps',
        name: 'Mein Standort',
        label: 'Mein Standort',
        lng: 13.4533,
        lat: 52.5065,
      );
    }
  }

  Future<void> _openOriginSearch(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<Location>(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
    if (result == null || !context.mounted) return;
    final origin = result.id == 'gps' ? await _resolveGps() : result;
    if (!context.mounted) return;
    if (result.id != 'gps') {
      ref.read(searchHistoryProvider.notifier).remember(result);
    }
    ref.read(routeControllerProvider.notifier).setOrigin(origin);
  }

  Future<void> _openDestinationSearch(
      BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<Location>(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
    if (result == null || !context.mounted) return;
    final destination = result.id == 'gps' ? await _resolveGps() : result;
    if (!context.mounted) return;
    if (result.id != 'gps') {
      ref.read(searchHistoryProvider.notifier).remember(result);
    }
    ref.read(routeControllerProvider.notifier).setDestination(destination);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeState = ref.watch(routeControllerProvider);
    final origin = routeState.origin;
    final destination = routeState.destination;

    final isGpsOrigin = origin == null || origin.id == 'gps';
    final originLabel = isGpsOrigin ? 'Mein Standort' : origin!.name;
    final destLabel = destination?.name;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () => _openOriginSearch(context, ref),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.my_location, size: 20, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      originLabel,
                      style: Theme.of(context).textTheme.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 48),
          InkWell(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(16)),
            onTap: () => _openDestinationSearch(context, ref),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 20,
                    color: destLabel != null ? Colors.red : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      destLabel ?? 'Wohin?',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: destLabel != null ? null : Colors.grey,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2.4: Run route_card tests — expect pass**

```bash
cd /Users/pv/code/beebeebike/.claude/worktrees/suspicious-brattain-efe4cf
cd mobile && flutter test test/widgets/route_card_test.dart 2>&1 | tail -20
```

Expected: All 4 tests pass.

- [ ] **Step 2.5: Commit**

```bash
cd /Users/pv/code/beebeebike/.claude/worktrees/suspicious-brattain-efe4cf
git add mobile/lib/widgets/route_card.dart mobile/test/widgets/route_card_test.dart
git commit -m "feat(mobile): add RouteCard widget with two-field origin/destination"
```

---

## Task 3: Wire RouteCard into map_screen.dart

**Files:**
- Modify: `mobile/lib/screens/map_screen.dart`

**Changes:**
1. Replace `BeeBeeBikeSearchBar` with `RouteCard` + `CircleAvatar` (settings button) in `_BrowseOverlay`
2. Remove unused imports: `GeocodeResult`, `search_bar.dart`, `search_screen.dart`
3. Update `_handleMapTap`: rename `'Current location'` → `'Mein Standort'`
4. Update `_refreshPreviewFromGps`: rename `'Current location'` → `'Mein Standort'`

- [ ] **Step 3.1: Update imports in map_screen.dart**

Remove these 3 import lines:
```dart
import '../models/geocode_result.dart';
import '../screens/search_screen.dart';
import '../widgets/search_bar.dart';
```

Add this import:
```dart
import '../widgets/route_card.dart';
```

The `settings_screen.dart` import is already present — keep it (still used for the avatar button).

- [ ] **Step 3.2: Update string labels in _handleMapTap and _refreshPreviewFromGps**

In `_handleMapTap` (around line 67-75), change:
```dart
notifier.setOrigin(
  Location(
    id: 'gps',
    name: 'Current location',
    label: 'Current location',
    lng: pos?.longitude ?? 13.4533,
    lat: pos?.latitude ?? 52.5065,
  ),
);
```
→
```dart
notifier.setOrigin(
  Location(
    id: 'gps',
    name: 'Mein Standort',
    label: 'Mein Standort',
    lng: pos?.longitude ?? 13.4533,
    lat: pos?.latitude ?? 52.5065,
  ),
);
```

In `_refreshPreviewFromGps` (around line 268-276), change:
```dart
ref.read(routeControllerProvider.notifier).setOrigin(
      Location(
        id: 'gps',
        name: 'Current location',
        label: 'Current location',
        lat: pos.latitude,
        lng: pos.longitude,
      ),
    );
```
→
```dart
ref.read(routeControllerProvider.notifier).setOrigin(
      Location(
        id: 'gps',
        name: 'Mein Standort',
        label: 'Mein Standort',
        lat: pos.latitude,
        lng: pos.longitude,
      ),
    );
```

- [ ] **Step 3.3: Replace _BrowseOverlay build() top section**

In `_BrowseOverlay.build()`, replace the `BeeBeeBikeSearchBar(...)` widget (lines 425–463) with:

```dart
SafeArea(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        const Expanded(child: RouteCard()),
        const SizedBox(width: 12),
        CircleAvatar(
          child: IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ),
      ],
    ),
  ),
),
```

The bottom sheet portion of `_BrowseOverlay.build()` (the `Align(alignment: Alignment.bottomCenter, ...)` block with `RouteSummary`) is **unchanged**.

- [ ] **Step 3.4: Run full test suite**

```bash
cd /Users/pv/code/beebeebike/.claude/worktrees/suspicious-brattain-efe4cf
just test-mobile 2>&1 | tail -50
```

Expected: All tests pass. If `map_screen_test.dart` has any test that references the old "Current location" string, update those to "Mein Standort".

- [ ] **Step 3.5: Commit**

```bash
cd /Users/pv/code/beebeebike/.claude/worktrees/suspicious-brattain-efe4cf
git add mobile/lib/screens/map_screen.dart
git commit -m "feat(mobile): replace search bar with RouteCard in browse overlay"
```

---

## Task 4: Preview and verify

- [ ] **Step 4.1: Start preview stack**

```bash
cd /Users/pv/code/beebeebike/.claude/worktrees/suspicious-brattain-efe4cf
just preview
```

Note the URL printed. Open it in Safari or Chrome.

- [ ] **Step 4.2: Manual checks**

In browse mode (no route planned):
- Route card visible at top with "Mein Standort" (origin) and "Wohin?" (destination)
- Avatar/settings button visible at top-right

Tap destination field:
- Search screen opens
- "Mein Standort" appears as first item
- Empty state shows no history (first use)
- Typing "Alex" shows Alexanderplatz results after debounce

Select a destination:
- Route card destination field updates to selected name
- Route preview computes and bottom sheet shows duration/distance

Tap origin field:
- Search screen opens with "Mein Standort" at top
- Select "Mein Standort" → origin stays "Mein Standort", route recomputes from GPS
- (Or type a custom origin) → origin field updates, route recomputes

After selecting a destination and re-opening search:
- Selected destination appears in history section

Tap a map location:
- Destination updates to dropped pin coordinates
- Route recomputes (origin stays as-is)

- [ ] **Step 4.3: Final commit if clean**

```bash
cd /Users/pv/code/beebeebike/.claude/worktrees/suspicious-brattain-efe4cf
git log --oneline -5
```
