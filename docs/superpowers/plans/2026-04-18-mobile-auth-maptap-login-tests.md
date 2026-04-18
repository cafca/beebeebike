# BeeBeeBike Mobile: Auth Bootstrap, Map Tap Fix, Login & Widget Tests

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix anonymous session bootstrap, map tap destination setting, and login screen; cover all user-facing flows with widget tests.

**Architecture:** Auth is eagerly initialized in `BeeBeeBikeApp` so the session cookie is ready before any route API call. Map tap replaces the unreliable native `onMapClick` (broken on iOS 26) with a Flutter `GestureDetector` + `MapLibreMapController.toLatLng()`. Login screen wires into the existing `authControllerProvider.login()`. Widget tests use `InterceptorsWrapper` to mock the backend and verify each screen's behaviour without a running server.

**Tech Stack:** Flutter 3.19+, Dart 3.3+, Riverpod 2.x, maplibre_gl ^0.20.0, Dio 5 + `InterceptorsWrapper` for mocking, `flutter_test`, `mocktail`.

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Modify | `mobile/lib/app.dart` | Eagerly watch `authControllerProvider` |
| Modify | `mobile/lib/screens/map_screen.dart` | ConsumerStatefulWidget, `onMapCreated`, GestureDetector tap |
| Create | `mobile/lib/screens/login_screen.dart` | Email/password login form |
| Modify | `mobile/lib/screens/settings_screen.dart` | Enable "Log in" tile → navigate to LoginScreen |
| Create | `mobile/test/helpers/test_helpers.dart` | Mock Dio, TestFixtures, `buildTestWidget` helper |
| Create | `mobile/test/screens/search_screen_test.dart` | Search flow widget tests |
| Create | `mobile/test/screens/map_screen_test.dart` | Route preview, error, Start button widget tests |
| Create | `mobile/test/screens/settings_login_test.dart` | Auth state display + login form tests |

---

## Task 1: Eagerly Bootstrap Anonymous Session on App Startup

**Files:**
- Modify: `mobile/lib/app.dart`

The `authControllerProvider` is lazy by default — it only initialises when first `watch`ed. Nothing on the map screen watches it, so the session cookie is not set before route API calls. Watching it in `BeeBeeBikeApp.build()` ensures the `/api/auth/anonymous` call completes before the user can interact.

- [ ] **Step 1: Write the failing test**

Add to `mobile/test/app_smoke_test.dart` inside `main()`:

```dart
testWidgets('auth provider is initialised on startup', (tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
  int authMeCallCount = 0;
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      if (options.path == '/api/auth/me') {
        authMeCallCount++;
        handler.reject(DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 401),
        ));
      } else if (options.path == '/api/auth/anonymous') {
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {'id': 'anon-1', 'account_type': 'anonymous', 'display_name': ''},
        ));
      } else {
        handler.next(options);
      }
    },
  ));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(const AppConfig(
          apiBaseUrl: 'http://localhost:3000',
          tileStyleUrl: 'http://localhost:8080/tiles/style.json',
        )),
        dioProvider.overrideWithValue(dio),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const BeeBeeBikeApp(),
    ),
  );
  await tester.pump(); // let async providers settle

  expect(authMeCallCount, equals(1),
      reason: 'authControllerProvider must be initialised on app startup');
});
```

Also add the necessary imports at the top of `app_smoke_test.dart`:

```dart
import 'package:beebeebike/api/client.dart';
import 'package:dio/dio.dart';
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
cd mobile && flutter test test/app_smoke_test.dart -v
```

Expected: FAIL — `authMeCallCount` is 0 because `authControllerProvider` is never initialised.

- [ ] **Step 3: Modify `app.dart` to watch auth on every build**

Replace `BeeBeeBikeApp` with a `ConsumerWidget` that watches `authControllerProvider`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_config.dart';
import 'providers/auth_provider.dart';
import 'screens/map_screen.dart';

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());

class BeeBeeBikeApp extends ConsumerWidget {
  const BeeBeeBikeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly initialise auth so the session cookie is ready before any
    // route/geocode API call. The value is intentionally ignored here.
    ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'BeeBeeBike',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E6F66),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F3EC),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}
```

- [ ] **Step 4: Run the test to confirm it passes**

```bash
cd mobile && flutter test test/app_smoke_test.dart -v
```

Expected: all tests PASS including the new one.

- [ ] **Step 5: Run the full test suite to check for regressions**

```bash
cd mobile && flutter test
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/app.dart mobile/test/app_smoke_test.dart
git commit -m "feat(mobile): eagerly bootstrap anonymous auth session on app startup"
```

---

## Task 2: Fix Map Tap — GestureDetector + MapLibreMapController.toLatLng

**Files:**
- Modify: `mobile/lib/screens/map_screen.dart`

The native `onMapClick` callback in `maplibre_gl` does not fire on iOS 26. Replace it with a Flutter-level `GestureDetector` that sits above the map (but below the search bar and bottom card), captures `onTapUp`, and converts the screen coordinate to a `LatLng` using `MapLibreMapController.toLatLng()`.

`MapScreen` must become a `ConsumerStatefulWidget` to hold the controller reference.

- [ ] **Step 1: Write the failing widget test**

Create `mobile/test/screens/map_screen_test.dart`:

```dart
import 'package:beebeebike/api/client.dart';
import 'package:beebeebike/config/app_config.dart';
import 'package:beebeebike/models/route_state.dart';
import 'package:beebeebike/providers/auth_provider.dart';
import 'package:beebeebike/providers/route_provider.dart';
import 'package:beebeebike/providers/search_history_provider.dart';
import 'package:beebeebike/screens/map_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('MapScreen route preview', () {
    testWidgets('shows CircularProgressIndicator while route is loading', (tester) async {
      final container = ProviderContainer(overrides: [
        ...testProviderOverrides(),
        routeControllerProvider.overrideWith(() => _LoadingRouteController()),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MapScreen()),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error card when route fails', (tester) async {
      final container = ProviderContainer(overrides: [
        ...testProviderOverrides(),
        routeControllerProvider.overrideWith(() => _ErrorRouteController()),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MapScreen()),
      ));
      await tester.pump();

      expect(find.text('Could not load route'), findsOneWidget);
    });

    testWidgets('shows RouteSummary with Start button when preview is available', (tester) async {
      final container = ProviderContainer(overrides: [
        ...testProviderOverrides(),
        routeControllerProvider.overrideWith(() => _PreviewRouteController()),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MapScreen()),
      ));
      await tester.pump();

      expect(find.text('Start'), findsOneWidget);
      expect(find.textContaining('min'), findsOneWidget);
    });

    testWidgets('Start button navigates to NavigationScreen', (tester) async {
      final container = ProviderContainer(overrides: [
        ...testProviderOverrides(),
        routeControllerProvider.overrideWith(() => _PreviewRouteController()),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MapScreen()),
      ));
      await tester.pump();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      // NavigationScreen has a close (X) button
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });
}

// Stub route controllers for testing state variants

class _LoadingRouteController extends RouteController {
  @override
  RouteState build() => const RouteState(isLoading: true);
}

class _ErrorRouteController extends RouteController {
  @override
  RouteState build() => const RouteState(error: 'routing failed');
}

class _PreviewRouteController extends RouteController {
  @override
  RouteState build() => RouteState(
        preview: _fakePreview(),
        origin: _fakeOrigin(),
        destination: _fakeDest(),
      );
}
```

The `_fakePreview`, `_fakeOrigin`, `_fakeDest` helpers and `testProviderOverrides()` are defined in Task 4.

- [ ] **Step 2: Run the test to confirm it fails (because `test_helpers.dart` doesn't exist yet)**

```bash
cd mobile && flutter test test/screens/map_screen_test.dart 2>&1 | head -20
```

Expected: compile error — `../helpers/test_helpers.dart` not found.

- [ ] **Step 3: Rewrite `map_screen.dart` as `ConsumerStatefulWidget`**

Replace the entire file:

```dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../app.dart';
import '../models/geocode_result.dart';
import '../models/location.dart';
import '../providers/route_provider.dart';
import '../screens/navigation_screen.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/route_summary.dart';
import '../widgets/search_bar.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapLibreMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    final routeState = ref.watch(routeControllerProvider);
    final preview = routeState.preview;

    return Scaffold(
      body: Stack(
        children: [
          MapLibreMap(
            styleString: ref.watch(appConfigProvider).tileStyleUrl,
            initialCameraPosition: const CameraPosition(
              target: LatLng(52.5200, 13.4050),
              zoom: 13,
            ),
            myLocationEnabled: true,
            myLocationTrackingMode: MyLocationTrackingMode.none,
            onMapCreated: (controller) {
              setState(() => _mapController = controller);
            },
          ),
          // Transparent tap layer — sits above the map but below UI widgets.
          // HitTestBehavior.translucent lets taps on the search bar and bottom
          // card fall through to those widgets' own recognizers.
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (details) async {
              final controller = _mapController;
              if (controller == null) return;
              final point = Point<double>(
                details.localPosition.dx,
                details.localPosition.dy,
              );
              final coords = await controller.toLatLng(point);
              if (!mounted) return;
              ref.read(routeControllerProvider.notifier).setDestination(
                    Location(
                      id: 'geo:${coords.latitude},${coords.longitude}',
                      name:
                          '${coords.latitude.toStringAsFixed(4)}, ${coords.longitude.toStringAsFixed(4)}',
                      label: 'Dropped pin',
                      lng: coords.longitude,
                      lat: coords.latitude,
                    ),
                  );
            },
            child: const SizedBox.expand(),
          ),
          BeeBeeBikeSearchBar(
            onTap: () async {
              final result = await Navigator.of(context).push<GeocodeResult>(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
              if (result == null || !context.mounted) return;

              Position? pos;
              try {
                pos = await Geolocator.getLastKnownPosition() ??
                    await Geolocator.getCurrentPosition();
              } catch (_) {}
              if (!context.mounted) return;
              ref.read(routeControllerProvider.notifier).setOrigin(
                    Location(
                      id: 'gps',
                      name: 'Current location',
                      label: 'Current location',
                      lng: pos?.longitude ?? 13.4533,
                      lat: pos?.latitude ?? 52.5065,
                    ),
                  );
              if (!context.mounted) return;
              ref.read(routeControllerProvider.notifier).setDestination(
                    Location(
                      id: result.id,
                      name: result.name,
                      label: result.label,
                      lng: result.lng,
                      lat: result.lat,
                    ),
                  );
            },
            onAvatarTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton(
                    onPressed: () {},
                    child: const Icon(Icons.my_location),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: routeState.isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : routeState.error != null
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: Colors.red),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Could not load route',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium,
                                  ),
                                ],
                              )
                            : preview == null
                                ? const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Center(
                                        child: SizedBox(
                                          width: 36,
                                          child: Divider(thickness: 4),
                                        ),
                                      ),
                                      SizedBox(height: 12),
                                      Text('Home'),
                                      Text('Saved places'),
                                    ],
                                  )
                                : RouteSummary(
                                    durationMinutes:
                                        (preview.time / 60).round(),
                                    distanceKm: preview.distance / 1000,
                                    onStart: () =>
                                        Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const NavigationScreen(),
                                      ),
                                    ),
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

- [ ] **Step 4: Run `flutter analyze` to confirm no errors**

```bash
cd mobile && flutter analyze lib/screens/map_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/map_screen.dart
git commit -m "fix(mobile): replace onMapClick with GestureDetector+toLatLng for iOS 26 compat"
```

---

## Task 3: Login Screen

**Files:**
- Create: `mobile/lib/screens/login_screen.dart`
- Modify: `mobile/lib/screens/settings_screen.dart`

The settings screen shows "Log in / Coming soon (disabled)" for anonymous users. Replace this with a working `LoginScreen`. `authControllerProvider.login(email, password)` already exists.

- [ ] **Step 1: Write the failing test**

Create `mobile/test/screens/settings_login_test.dart`:

```dart
import 'package:beebeebike/screens/login_screen.dart';
import 'package:beebeebike/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('SettingsScreen', () {
    testWidgets('shows Log in tile when anonymous', (tester) async {
      await tester.pumpWidget(buildTestWidget(const SettingsScreen()));
      await tester.pump();

      expect(find.text('Log in'), findsOneWidget);
      // Must be tappable — not disabled
      final tile = tester.widget<ListTile>(
        find.ancestor(of: find.text('Log in'), matching: find.byType(ListTile)),
      );
      expect(tile.enabled, isTrue);
    });

    testWidgets('tapping Log in navigates to LoginScreen', (tester) async {
      await tester.pumpWidget(buildTestWidget(const SettingsScreen()));
      await tester.pump();
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('shows email and Log out when authenticated', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        const SettingsScreen(),
        authenticated: true,
      ));
      await tester.pump();

      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.text('Log out'), findsOneWidget);
      expect(find.text('Log in'), findsNothing);
    });
  });

  group('LoginScreen', () {
    testWidgets('renders email and password fields and Log in button', (tester) async {
      await tester.pumpWidget(buildTestWidget(const LoginScreen()));
      await tester.pump();

      expect(find.byKey(const Key('login_email')), findsOneWidget);
      expect(find.byKey(const Key('login_password')), findsOneWidget);
      expect(find.text('Log in'), findsOneWidget);
    });

    testWidgets('shows error message on invalid credentials', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        const LoginScreen(),
        loginSucceeds: false,
      ));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('login_email')), 'bad@example.com');
      await tester.enterText(find.byKey(const Key('login_password')), 'wrong');
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password'), findsOneWidget);
    });

    testWidgets('pops on successful login', (tester) async {
      // Wrap in a Navigator so pop() can work
      await tester.pumpWidget(buildTestWidget(
        const LoginScreen(),
        authenticated: false,
        loginSucceeds: true,
      ));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('login_email')), 'test@example.com');
      await tester.enterText(find.byKey(const Key('login_password')), 'correct');
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      // After pop, LoginScreen should be gone
      expect(find.byType(LoginScreen), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run the test to confirm it fails (compile error — LoginScreen missing)**

```bash
cd mobile && flutter test test/screens/settings_login_test.dart 2>&1 | head -20
```

Expected: compile error — `login_screen.dart` not found.

- [ ] **Step 3: Create `login_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).login(
            _emailController.text.trim(),
            _passwordController.text,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Invalid email or password';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log in')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('login_email'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter your email' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('login_password'),
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter your password' : null,
              ),
              const SizedBox(height: 8),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Log in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Modify `settings_screen.dart` to enable Log in and navigate to LoginScreen**

Replace the `else` branch in `SettingsScreen.build()`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import 'login_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final home = ref.watch(homeLocationProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: Text(user?.email ?? 'Guest'),
            subtitle: Text(user?.accountType ?? 'Loading...'),
          ),
          if (home != null)
            ListTile(
              title: const Text('Home'),
              subtitle: Text(home.label),
            ),
          if (user?.email != null)
            ListTile(
              title: const Text('Log out'),
              onTap: () =>
                  ref.read(authControllerProvider.notifier).logout(),
            )
          else
            ListTile(
              title: const Text('Log in'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run `flutter analyze` on both files**

```bash
cd mobile && flutter analyze lib/screens/login_screen.dart lib/screens/settings_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/screens/login_screen.dart mobile/lib/screens/settings_screen.dart
git commit -m "feat(mobile): add login screen and wire settings to it"
```

---

## Task 4: Widget Test Helpers

**Files:**
- Create: `mobile/test/helpers/test_helpers.dart`

Shared utilities used by all widget tests in Tasks 5–7: mock Dio with `InterceptorsWrapper`, `TestFixtures` constants, and `buildTestWidget()` / `testProviderOverrides()` helpers.

- [ ] **Step 1: Create `test/helpers/test_helpers.dart`**

```dart
import 'package:beebeebike/api/client.dart';
import 'package:beebeebike/config/app_config.dart';
import 'package:beebeebike/models/location.dart';
import 'package:beebeebike/models/route_preview.dart';
import 'package:beebeebike/providers/search_history_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class TestFixtures {
  static const Map<String, dynamic> anonymousUser = {
    'id': 'anon-1',
    'account_type': 'anonymous',
    'display_name': '',
  };

  static const Map<String, dynamic> loggedInUser = {
    'id': 'user-1',
    'email': 'test@example.com',
    'display_name': 'Test User',
    'account_type': 'standard',
  };

  static const Map<String, dynamic> geocodeResponse = {
    'features': [
      {
        'geometry': {
          'coordinates': [13.4050, 52.5200]
        },
        'properties': {
          'osm_type': 'N',
          'osm_id': '42',
          'name': 'Alexanderplatz',
          'district': 'Mitte',
          'osm_value': 'station',
        },
      },
    ],
  };

  static const Map<String, dynamic> routePreviewJson = {
    'geometry': {
      'type': 'LineString',
      'coordinates': [
        [13.4050, 52.5200],
        [13.4533, 52.5065],
      ],
    },
    'distance': 5000.0,
    'time': 1200.0,
  };
}

RoutePreview fakePreview() => RoutePreview.fromJson(
    Map<String, dynamic>.from(TestFixtures.routePreviewJson));

Location fakeOrigin() => const Location(
    id: 'gps', name: 'Current location', label: 'Current location',
    lng: 13.4533, lat: 52.5065);

Location fakeDest() => const Location(
    id: 'N:42', name: 'Alexanderplatz', label: 'Mitte · station',
    lng: 13.4050, lat: 52.5200);

/// Builds a mock [Dio] instance that handles common backend endpoints.
///
/// [authenticated]: if true, `/api/auth/me` returns a logged-in user instead
///   of 401 + anonymous bootstrap.
/// [geocodeReturnsResults]: if false, geocode returns an empty feature list.
/// [routeSucceeds]: if false, `/api/route` returns 500.
/// [loginSucceeds]: if false, `/api/auth/login` returns 401.
Dio buildMockDio({
  bool authenticated = false,
  bool geocodeReturnsResults = true,
  bool routeSucceeds = true,
  bool loginSucceeds = true,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final path = options.path;

      if (path == '/api/auth/me') {
        if (authenticated) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: TestFixtures.loggedInUser,
          ));
        } else {
          handler.reject(DioException(
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: 401,
                data: {'error': 'unauthorized'}),
            type: DioExceptionType.badResponse,
          ));
        }
        return;
      }

      if (path == '/api/auth/anonymous') {
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: TestFixtures.anonymousUser,
        ));
        return;
      }

      if (path == '/api/auth/login') {
        if (loginSucceeds) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: TestFixtures.loggedInUser,
          ));
        } else {
          handler.reject(DioException(
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: 401,
                data: {'error': 'unauthorized'}),
            type: DioExceptionType.badResponse,
          ));
        }
        return;
      }

      if (path == '/api/auth/logout') {
        handler.resolve(Response(requestOptions: options, statusCode: 200));
        return;
      }

      if (path == '/api/geocode') {
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: geocodeReturnsResults
              ? TestFixtures.geocodeResponse
              : {'features': []},
        ));
        return;
      }

      if (path == '/api/route') {
        if (routeSucceeds) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: TestFixtures.routePreviewJson,
          ));
        } else {
          handler.reject(DioException(
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: 500),
            type: DioExceptionType.badResponse,
          ));
        }
        return;
      }

      if (path == '/api/locations/home') {
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 404,
        ));
        return;
      }

      handler.next(options);
    },
  ));
  return dio;
}

/// Riverpod overrides shared across widget tests.
List<Override> testProviderOverrides({
  bool authenticated = false,
  bool geocodeReturnsResults = true,
  bool routeSucceeds = true,
  bool loginSucceeds = true,
}) {
  SharedPreferences.setMockInitialValues({});
  return [
    appConfigProvider.overrideWithValue(const AppConfig(
      apiBaseUrl: 'http://localhost:3000',
      tileStyleUrl: 'http://localhost:8080/tiles/style.json',
    )),
    dioProvider.overrideWithValue(buildMockDio(
      authenticated: authenticated,
      geocodeReturnsResults: geocodeReturnsResults,
      routeSucceeds: routeSucceeds,
      loginSucceeds: loginSucceeds,
    )),
    sharedPreferencesProvider.overrideWith((_) async {
      SharedPreferences.setMockInitialValues({});
      return SharedPreferences.getInstance();
    }),
  ];
}

/// Wraps [child] in a [ProviderScope] with test overrides and a [MaterialApp].
///
/// Callers that need fine-grained provider control should use
/// [testProviderOverrides] + [UncontrolledProviderScope] directly.
Widget buildTestWidget(
  Widget child, {
  bool authenticated = false,
  bool geocodeReturnsResults = true,
  bool routeSucceeds = true,
  bool loginSucceeds = true,
}) {
  return ProviderScope(
    overrides: testProviderOverrides(
      authenticated: authenticated,
      geocodeReturnsResults: geocodeReturnsResults,
      routeSucceeds: routeSucceeds,
      loginSucceeds: loginSucceeds,
    ),
    child: MaterialApp(home: child),
  );
}
```

- [ ] **Step 2: Run `flutter analyze` on the helpers file**

```bash
cd mobile && flutter analyze test/helpers/test_helpers.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add mobile/test/helpers/test_helpers.dart
git commit -m "test(mobile): add widget test helpers with mock Dio and provider overrides"
```

---

## Task 5: SearchScreen Widget Tests

**Files:**
- Create: `mobile/test/screens/search_screen_test.dart`

Tests the full search flow: typing triggers a debounced API call, results appear as ListTiles, and tapping a result pops the route with the correct `GeocodeResult`.

- [ ] **Step 1: Write the tests**

```dart
import 'package:beebeebike/models/geocode_result.dart';
import 'package:beebeebike/screens/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('SearchScreen', () {
    testWidgets('shows search results after typing a query', (tester) async {
      await tester.pumpWidget(buildTestWidget(const SearchScreen()));
      await tester.pump();

      final field = find.byType(TextField);
      expect(field, findsOneWidget);

      await tester.enterText(field, 'Alex');
      // Wait for the 400 ms debounce + async search
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(); // let FutureBuilder/setState settle

      expect(find.text('Alexanderplatz'), findsOneWidget);
      expect(find.text('Mitte · station'), findsOneWidget);
    });

    testWidgets('shows empty list when query returns no results', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        const SearchScreen(),
        geocodeReturnsResults: false,
      ));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'nowhere');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('tapping a result pops with the selected GeocodeResult', (tester) async {
      GeocodeResult? returned;

      await tester.pumpWidget(ProviderScope(
        overrides: testProviderOverrides(),
        child: MaterialApp(
          home: Builder(builder: (ctx) {
            return ElevatedButton(
              onPressed: () async {
                returned = await Navigator.of(ctx).push<GeocodeResult>(
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                );
              },
              child: const Text('Open'),
            );
          }),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Alex');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      await tester.tap(find.text('Alexanderplatz'));
      await tester.pumpAndSettle();

      expect(returned, isNotNull);
      expect(returned!.name, equals('Alexanderplatz'));
      expect(returned!.id, equals('N:42'));
      expect(returned!.lng, closeTo(13.405, 0.001));
      expect(returned!.lat, closeTo(52.52, 0.001));
    });

    testWidgets('shows CircularProgressIndicator while loading', (tester) async {
      await tester.pumpWidget(buildTestWidget(const SearchScreen()));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Mitte');
      await tester.pump(const Duration(milliseconds: 500));
      // Don't pump again — catch the loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run the tests (they should fail since test_helpers.dart has compile errors without Task 4 being done first)**

Ensure Task 4 is complete, then:

```bash
cd mobile && flutter test test/screens/search_screen_test.dart -v
```

Expected: all 4 tests PASS.

- [ ] **Step 3: Commit**

```bash
git add mobile/test/screens/search_screen_test.dart
git commit -m "test(mobile): add SearchScreen widget tests"
```

---

## Task 6: MapScreen Widget Tests

**Files:**
- Modify: `mobile/test/screens/map_screen_test.dart`

Add the missing helper functions and imports that the stub test file from Task 2 needs, then verify all four cases: loading state, error state, route preview, and Start-button navigation.

- [ ] **Step 1: Finalize `map_screen_test.dart` with full imports and helpers**

Replace the stub created in Task 2 step 1 with the complete file:

```dart
import 'package:beebeebike/api/client.dart';
import 'package:beebeebike/config/app_config.dart';
import 'package:beebeebike/models/route_state.dart';
import 'package:beebeebike/providers/route_provider.dart';
import 'package:beebeebike/providers/search_history_provider.dart';
import 'package:beebeebike/screens/map_screen.dart';
import 'package:beebeebike/screens/navigation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('MapScreen route card', () {
    testWidgets('shows CircularProgressIndicator while route is loading', (tester) async {
      final container = ProviderContainer(overrides: [
        ...testProviderOverrides(),
        routeControllerProvider.overrideWith(_LoadingRouteController.new),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MapScreen()),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows "Could not load route" when route fails', (tester) async {
      final container = ProviderContainer(overrides: [
        ...testProviderOverrides(),
        routeControllerProvider.overrideWith(_ErrorRouteController.new),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MapScreen()),
      ));
      await tester.pump();

      expect(find.text('Could not load route'), findsOneWidget);
    });

    testWidgets('shows RouteSummary with duration and distance when preview is ready', (tester) async {
      final container = ProviderContainer(overrides: [
        ...testProviderOverrides(),
        routeControllerProvider.overrideWith(_PreviewRouteController.new),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MapScreen()),
      ));
      await tester.pump();

      expect(find.text('Start'), findsOneWidget);
      // 1200 s / 60 = 20 min, 5000 m / 1000 = 5.0 km
      expect(find.textContaining('20 min'), findsOneWidget);
      expect(find.textContaining('5.0 km'), findsOneWidget);
    });

    testWidgets('Start button pushes NavigationScreen', (tester) async {
      final container = ProviderContainer(overrides: [
        ...testProviderOverrides(),
        routeControllerProvider.overrideWith(_PreviewRouteController.new),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MapScreen()),
      ));
      await tester.pump();
      await tester.tap(find.text('Start'));
      await tester.pump(); // begin navigation screen init

      // NavigationScreen shows the close button
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('shows placeholder text when no route is set', (tester) async {
      await tester.pumpWidget(buildTestWidget(const MapScreen()));
      await tester.pump();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Saved places'), findsOneWidget);
    });
  });
}

class _LoadingRouteController extends RouteController {
  @override
  RouteState build() => const RouteState(isLoading: true);
}

class _ErrorRouteController extends RouteController {
  @override
  RouteState build() => const RouteState(error: 'routing failed');
}

class _PreviewRouteController extends RouteController {
  @override
  RouteState build() => RouteState(
        preview: fakePreview(),
        origin: fakeOrigin(),
        destination: fakeDest(),
      );
}
```

- [ ] **Step 2: Run the tests**

```bash
cd mobile && flutter test test/screens/map_screen_test.dart -v
```

Expected: all 5 tests PASS.

- [ ] **Step 3: Commit**

```bash
git add mobile/test/screens/map_screen_test.dart
git commit -m "test(mobile): add MapScreen widget tests for route card states"
```

---

## Task 7: SettingsScreen & LoginScreen Widget Tests

**Files:**
- Finalize: `mobile/test/screens/settings_login_test.dart`

The stub in Task 3 step 1 already has the full test content. After Tasks 3 and 4 are complete, this file should compile and all tests should pass.

- [ ] **Step 1: Run the tests**

```bash
cd mobile && flutter test test/screens/settings_login_test.dart -v
```

Expected:
```
✓ SettingsScreen shows Log in tile when anonymous
✓ SettingsScreen tapping Log in navigates to LoginScreen
✓ SettingsScreen shows email and Log out when authenticated
✓ LoginScreen renders email and password fields and Log in button
✓ LoginScreen shows error message on invalid credentials
✓ LoginScreen pops on successful login
```

- [ ] **Step 2: If any test fails, debug**

For the "pops on successful login" test: `loginSucceeds: true` is the default. The `_submit()` method calls `authControllerProvider.login()` and then pops. If the provider is not being overridden correctly in `buildTestWidget`, the real Dio will be used and the login will fail. Verify that `dioProvider` is correctly overridden in `buildTestWidget`.

For the "shows error message" test: `loginSucceeds: false` causes the mock Dio to return 401 for `/api/auth/login`. The `_submit()` method catches the `DioException` and sets `_error = 'Invalid email or password'`. If the test fails, add a print to `_submit()` to confirm the catch block runs.

- [ ] **Step 3: Run the full test suite**

```bash
cd mobile && flutter test
```

Expected output (12 existing + new tests):
```
All tests passed!
```

- [ ] **Step 4: Commit**

```bash
git add mobile/test/screens/settings_login_test.dart
git commit -m "test(mobile): add SettingsScreen and LoginScreen widget tests"
```

---

## Self-Review

**Spec coverage:**
- ✅ UI tests surface "searching doesn't turn up results" → SearchScreen test #1 and #2
- ✅ UI tests surface "tapping search result doesn't result in route" → SearchScreen test #3 checks return value; MapScreen test setup validates route state → RouteSummary
- ✅ UI tests surface "tapping map doesn't result in navigation" → MapScreen test "Start button pushes NavigationScreen"
- ✅ Anonymous session on app startup → Task 1 (authControllerProvider watched in BeeBeeBikeApp, test asserts /api/auth/me called on startup)
- ✅ onMapClick fixed → Task 2 (GestureDetector + toLatLng)
- ✅ Login fixed → Task 3 (LoginScreen + settings wire-up)
- ✅ Widget tests exercise all features → Tasks 5–7

**Placeholder scan:** None found.

**Type consistency:**
- `fakePreview()`, `fakeOrigin()`, `fakeDest()` defined in `test_helpers.dart` and used by both `map_screen_test.dart` and `settings_login_test.dart` (indirectly).
- `RouteController` subclasses (`_LoadingRouteController`, etc.) override `build()` returning `RouteState` — matches the `NotifierProvider<RouteController, RouteState>` declaration.
- `buildTestWidget` and `testProviderOverrides` parameter names match across all usage sites.
