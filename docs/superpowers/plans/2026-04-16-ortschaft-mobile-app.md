# Ortschaft Mobile App v0.1 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Flutter mobile client in `mobile/` that reproduces BeeBeeBike's routing and overlay experience on iOS/Android, then adds turn-by-turn navigation by consuming the new backend `/api/navigate` endpoint and the standalone `ferrostar_flutter` plugin from Plan A.

**Architecture:** `mobile/` is a thin Flutter client. Dio talks to the existing backend for auth, geocoding, preview routing, ratings overlay, home location, and navigation-route JSON. Riverpod owns session, route preview, navigation, and settings state. `maplibre_gl` renders the map; a separate `NavigationService` orchestrates `ferrostar_flutter`, `geolocator`, `flutter_compass`, and `flutter_tts` so UI widgets stay declarative.

**Tech Stack:** Flutter 3.19+, Dart 3.3+, `flutter_riverpod`, `dio`, `dio_cookie_manager`, `cookie_jar`, `maplibre_gl`, `geolocator`, `flutter_compass`, `flutter_tts`, `freezed`, `json_serializable`, `shared_preferences`, path dependency on `../packages/ferrostar_flutter`.

**Parent spec:** `docs/superpowers/specs/2026-04-16-mobile-navigation-app-design.md`

**Dependencies:** Plan A must provide `packages/ferrostar_flutter/`. Plan B must provide `POST /api/navigate`. This plan assumes both exist by the time Task 6 starts.

---

## File Structure

```
mobile/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── config/
│   │   └── app_config.dart              # Base URLs and environment-driven config
│   ├── api/
│   │   ├── client.dart
│   │   ├── auth_api.dart
│   │   ├── routing_api.dart
│   │   ├── ratings_api.dart
│   │   ├── geocode_api.dart
│   │   └── locations_api.dart
│   ├── models/
│   │   ├── user.dart
│   │   ├── route_preview.dart
│   │   ├── location.dart
│   │   ├── geocode_result.dart
│   │   └── route_state.dart
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   ├── location_provider.dart
│   │   ├── route_provider.dart
│   │   ├── search_history_provider.dart
│   │   └── navigation_provider.dart
│   ├── navigation/
│   │   ├── navigation_service.dart
│   │   └── camera_controller.dart
│   ├── screens/
│   │   ├── map_screen.dart
│   │   ├── search_screen.dart
│   │   ├── navigation_screen.dart
│   │   └── settings_screen.dart
│   └── widgets/
│       ├── search_bar.dart
│       ├── route_summary.dart
│       ├── turn_banner.dart
│       └── rating_overlay.dart
├── test/
│   ├── app_smoke_test.dart
│   ├── api/
│   │   └── routing_api_test.dart
│   ├── providers/
│   │   ├── auth_provider_test.dart
│   │   └── route_provider_test.dart
│   └── navigation/
│       ├── navigation_service_test.dart
│       └── camera_controller_test.dart
├── analysis_options.yaml
├── pubspec.yaml
└── README.md
```

---

## Phase 1: Scaffold the App

### Task 1: Create the Flutter app and wire repo-level hygiene

**Files:**
- Modify: `.gitignore`
- Create: `mobile/` (generated scaffold)
- Modify: `mobile/pubspec.yaml`
- Create: `mobile/lib/main.dart`
- Create: `mobile/lib/app.dart`
- Create: `mobile/lib/config/app_config.dart`
- Create: `mobile/test/app_smoke_test.dart`
- Create: `mobile/README.md`

- [ ] **Step 1: Scaffold the app**

```bash
cd /Users/pv/code/ortschaft
flutter create \
  --org=land._001 \
  --project-name=ortschaft \
  --platforms=ios,android \
  mobile
```

- [ ] **Step 2: Add Flutter-specific ignore rules**

Append these lines to the root `.gitignore`:

```gitignore
# Flutter
**/.dart_tool/
**/.flutter-plugins
**/.flutter-plugins-dependencies
**/.packages
**/flutter_export_environment.sh
**/Pods/
**/.symlinks/
```

- [ ] **Step 3: Replace the generated `pubspec.yaml` with app dependencies**

Use this dependency set in `mobile/pubspec.yaml`:

```yaml
name: ortschaft
description: Mobile navigation client for BeeBeeBike / Ortschaft.
publish_to: none
version: 0.1.0+1

environment:
  sdk: ^3.3.0
  flutter: ^3.19.0

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  flutter_riverpod: ^2.5.1
  dio: ^5.7.0
  dio_cookie_manager: ^3.1.1
  cookie_jar: ^4.0.8
  maplibre_gl: ^0.20.0
  geolocator: ^13.0.1
  flutter_compass: ^0.8.1
  flutter_tts: ^4.0.2
  shared_preferences: ^2.3.2
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  ferrostar_flutter:
    path: ../packages/ferrostar_flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  build_runner: ^2.4.13
  freezed: ^2.5.7
  json_serializable: ^6.9.0
  http_mock_adapter: ^0.6.1
  mocktail: ^1.0.4

flutter:
  uses-material-design: true
```

- [ ] **Step 4: Add environment-driven app config**

Create `mobile/lib/config/app_config.dart`:

```dart
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.tileStyleUrl,
  });

  final String apiBaseUrl;
  final String tileStyleUrl;

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      apiBaseUrl: String.fromEnvironment(
        'ORTSCHAFT_API_BASE_URL',
        defaultValue: 'https://maps.001.land',
      ),
      tileStyleUrl: String.fromEnvironment(
        'ORTSCHAFT_TILE_STYLE_URL',
        defaultValue: 'https://maps.001.land/tiles/assets/styles/colorful/style.json',
      ),
    );
  }
}
```

- [ ] **Step 5: Replace the generated app entrypoint**

Create `mobile/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config/app_config.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(AppConfig.fromEnvironment()),
      ],
      child: const OrtschaftApp(),
    ),
  );
}
```

Create `mobile/lib/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_config.dart';
import 'screens/map_screen.dart';

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());

class OrtschaftApp extends StatelessWidget {
  const OrtschaftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ortschaft',
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

- [ ] **Step 6: Add a smoke test and developer README**

Create `mobile/test/app_smoke_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ortschaft/app.dart';
import 'package:ortschaft/config/app_config.dart';

void main() {
  testWidgets('boots to the map screen shell', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'http://localhost:3000',
              tileStyleUrl: 'http://localhost:8080/tiles/assets/styles/colorful/style.json',
            ),
          ),
        ],
        child: const OrtschaftApp(),
      ),
    );

    expect(find.text('Search here...'), findsOneWidget);
  });
}
```

Create `mobile/README.md`:

````markdown
# Ortschaft mobile

Run locally:

```bash
flutter pub get
flutter run \
  --dart-define=ORTSCHAFT_API_BASE_URL=http://10.0.2.2:3000 \
  --dart-define=ORTSCHAFT_TILE_STYLE_URL=http://10.0.2.2:8080/tiles/assets/styles/colorful/style.json
```
````

- [ ] **Step 7: Run the scaffold verification**

```bash
cd /Users/pv/code/ortschaft/mobile
flutter pub get
flutter test test/app_smoke_test.dart
```
Expected: `flutter pub get` succeeds, then the smoke test fails because `MapScreen` does not exist yet.

- [ ] **Step 8: Commit the scaffold**

```bash
cd /Users/pv/code/ortschaft
git add .gitignore mobile
git commit -m "chore(mobile): scaffold ortschaft flutter app"
```

---

## Phase 2: Data Layer

### Task 2: Add immutable models and Dio-backed API clients

**Files:**
- Create: `mobile/lib/models/user.dart`
- Create: `mobile/lib/models/location.dart`
- Create: `mobile/lib/models/route_preview.dart`
- Create: `mobile/lib/models/geocode_result.dart`
- Create: `mobile/lib/models/route_state.dart`
- Create: `mobile/lib/api/client.dart`
- Create: `mobile/lib/api/auth_api.dart`
- Create: `mobile/lib/api/routing_api.dart`
- Create: `mobile/lib/api/ratings_api.dart`
- Create: `mobile/lib/api/geocode_api.dart`
- Create: `mobile/lib/api/locations_api.dart`
- Create: `mobile/test/api/routing_api_test.dart`

- [ ] **Step 1: Write a failing routing API test**

Create `mobile/test/api/routing_api_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:ortschaft/api/routing_api.dart';

void main() {
  test('computeNavigationRoute returns raw JSON from /api/navigate', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://maps.001.land'));
    final adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;

    const response = {
      'routes': [
        {
          'distance': 1234.5,
          'geometry': 'abc123',
        }
      ],
    };

    adapter.onPost(
      '/api/navigate',
      (server) => server.reply(200, response),
      data: {
        'origin': [13.405, 52.52],
        'destination': [13.45, 52.51],
        'rating_weight': 0.5,
        'distance_influence': 70.0,
      },
    );

    final api = RoutingApi(dio);
    final json = await api.computeNavigationRoute(
      const [13.405, 52.52],
      const [13.45, 52.51],
      ratingWeight: 0.5,
      distanceInfluence: 70.0,
    );

    expect(json['routes'][0]['distance'], 1234.5);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /Users/pv/code/ortschaft/mobile
flutter test test/api/routing_api_test.dart
```
Expected: missing imports/classes such as `RoutingApi`.

- [ ] **Step 3: Implement the core models**

Create `mobile/lib/models/user.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User with _$User {
  const factory User({
    required String id,
    String? email,
    @JsonKey(name: 'display_name') String? displayName,
    @JsonKey(name: 'account_type') required String accountType,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
```

Create `mobile/lib/models/location.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'location.freezed.dart';
part 'location.g.dart';

@freezed
class Location with _$Location {
  const factory Location({
    required String id,
    required String name,
    required String label,
    required double lng,
    required double lat,
  }) = _Location;

  factory Location.fromJson(Map<String, dynamic> json) => _$LocationFromJson(json);
}
```

Create `mobile/lib/models/route_preview.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'route_preview.freezed.dart';
part 'route_preview.g.dart';

@freezed
class RoutePreview with _$RoutePreview {
  const factory RoutePreview({
    required Map<String, dynamic> geometry,
    required double distance,
    required double time,
  }) = _RoutePreview;

  factory RoutePreview.fromJson(Map<String, dynamic> json) =>
      _$RoutePreviewFromJson(json);
}
```

- [ ] **Step 4: Implement the shared Dio client and endpoint wrappers**

Create `mobile/lib/api/client.dart`:

```dart
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      headers: const {'Content-Type': 'application/json'},
    ),
  );
  dio.interceptors.add(CookieManager(CookieJar()));
  return dio;
});
```

Create `mobile/lib/api/auth_api.dart`:

```dart
import 'package:dio/dio.dart';

import '../models/user.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<User> anonymous() async =>
      User.fromJson((await _dio.post('/api/auth/anonymous')).data as Map<String, dynamic>);

  Future<User> me() async =>
      User.fromJson((await _dio.get('/api/auth/me')).data as Map<String, dynamic>);

  Future<User> login(String email, String password) async => User.fromJson(
        (await _dio.post('/api/auth/login', data: {
          'email': email,
          'password': password,
        }))
            .data as Map<String, dynamic>,
      );

  Future<User> register(String email, String password, String? displayName) async =>
      User.fromJson(
        (await _dio.post('/api/auth/register', data: {
          'email': email,
          'password': password,
          'display_name': displayName,
        }))
            .data as Map<String, dynamic>,
      );

  Future<void> logout() async {
    await _dio.post('/api/auth/logout');
  }
}
```

Create `mobile/lib/api/routing_api.dart`:

```dart
import 'package:dio/dio.dart';

import '../models/route_preview.dart';

class RoutingApi {
  RoutingApi(this._dio);

  final Dio _dio;

  Future<RoutePreview> computeRoute(
    List<double> origin,
    List<double> destination, {
    double? ratingWeight,
    double? distanceInfluence,
  }) async {
    final response = await _dio.post('/api/route', data: {
      'origin': origin,
      'destination': destination,
      'rating_weight': ratingWeight,
      'distance_influence': distanceInfluence,
    });
    return RoutePreview.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> computeNavigationRoute(
    List<double> origin,
    List<double> destination, {
    double? ratingWeight,
    double? distanceInfluence,
  }) async {
    final response = await _dio.post('/api/navigate', data: {
      'origin': origin,
      'destination': destination,
      'rating_weight': ratingWeight,
      'distance_influence': distanceInfluence,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }
}
```

- [ ] **Step 5: Generate code and make the test pass**

```bash
cd /Users/pv/code/ortschaft/mobile
dart run build_runner build --delete-conflicting-outputs
flutter test test/api/routing_api_test.dart
```
Expected: generated files appear and the routing API test passes.

- [ ] **Step 6: Commit the data layer**

```bash
cd /Users/pv/code/ortschaft
git add mobile/lib/models mobile/lib/api mobile/test/api
git commit -m "feat(mobile): add freezed models and dio api clients"
```

---

## Phase 3: Session, Home, and Search State

### Task 3: Bootstrap anonymous auth and persistent user-facing state

**Files:**
- Create: `mobile/lib/providers/auth_provider.dart`
- Create: `mobile/lib/providers/location_provider.dart`
- Create: `mobile/lib/providers/search_history_provider.dart`
- Create: `mobile/lib/screens/settings_screen.dart`
- Create: `mobile/test/providers/auth_provider_test.dart`

- [ ] **Step 1: Write a failing auth bootstrap test**

Create `mobile/test/providers/auth_provider_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:ortschaft/api/client.dart';
import 'package:ortschaft/providers/auth_provider.dart';

void main() {
  test('bootstraps anonymous session when /api/auth/me returns 401', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://maps.001.land'));
    final adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;

    adapter.onGet('/api/auth/me', (server) => server.reply(401, {'error': 'unauthorized'}));
    adapter.onPost(
      '/api/auth/anonymous',
      (server) => server.reply(200, {
        'id': 'user-1',
        'account_type': 'anonymous',
        'email': null,
      }),
    );

    final container = ProviderContainer(overrides: [
      dioProvider.overrideWithValue(dio),
    ]);
    addTearDown(container.dispose);

    final user = await container.read(authControllerProvider.future);
    expect(user?.accountType, 'anonymous');
  });
}
```

- [ ] **Step 2: Implement the auth and location providers**

Create `mobile/lib/providers/auth_provider.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/auth_api.dart';
import '../api/client.dart';
import '../models/user.dart';

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref.watch(dioProvider)));

final authControllerProvider =
    AsyncNotifierProvider<AuthController, User?>(AuthController.new);

class AuthController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final api = ref.read(authApiProvider);
    try {
      return await api.me();
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        return api.anonymous();
      }
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authApiProvider).login(email, password));
  }

  Future<void> register(String email, String password, String? displayName) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authApiProvider).register(email, password, displayName),
    );
  }

  Future<void> logout() async {
    await ref.read(authApiProvider).logout();
    state = await AsyncValue.guard(() => ref.read(authApiProvider).anonymous());
  }
}
```

Create `mobile/lib/providers/location_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../models/location.dart';

class LocationsApi {
  LocationsApi(this._dio);

  final dynamic _dio;

  Future<Location?> getHome() async {
    final response = await _dio.get('/api/locations/home');
    final data = response.data;
    if (data == null) return null;
    return Location.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Location> setHome(Location location) async {
    final response = await _dio.put('/api/locations/home', data: {
      'label': location.label,
      'lng': location.lng,
      'lat': location.lat,
    });
    return Location.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<void> deleteHome() async {
    await _dio.delete('/api/locations/home');
  }
}

final locationsApiProvider = Provider<LocationsApi>(
  (ref) => LocationsApi(ref.watch(dioProvider)),
);

final homeLocationProvider =
    AsyncNotifierProvider<HomeLocationController, Location?>(HomeLocationController.new);

class HomeLocationController extends AsyncNotifier<Location?> {
  @override
  Future<Location?> build() => ref.read(locationsApiProvider).getHome();

  Future<void> save(Location location) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(locationsApiProvider).setHome(location));
  }

  Future<void> clear() async {
    await ref.read(locationsApiProvider).deleteHome();
    state = const AsyncData(null);
  }
}
```

- [ ] **Step 3: Implement recent-search persistence**

Create `mobile/lib/providers/search_history_provider.dart`:

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/location.dart';

const _recentSearchesKey = 'ortschaft.recentSearches';

final sharedPreferencesProvider = Provider<SharedPreferences>((_) {
  throw UnimplementedError('override in main/test');
});

final searchHistoryProvider =
    NotifierProvider<SearchHistoryController, List<Location>>(SearchHistoryController.new);

class SearchHistoryController extends Notifier<List<Location>> {
  @override
  List<Location> build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getStringList(_recentSearchesKey) ?? const [];
    return raw
        .map((entry) => Location.fromJson(jsonDecode(entry) as Map<String, dynamic>))
        .toList();
  }

  Future<void> remember(Location location) async {
    final next = [
      location,
      ...state.where((entry) => entry.id != location.id),
    ].take(10).toList();
    state = next;

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(
      _recentSearchesKey,
      next.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
  }
}
```

- [ ] **Step 4: Add the minimal settings screen**

Create `mobile/lib/screens/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';

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
          ListTile(
            title: const Text('Log out'),
            onTap: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run provider tests**

```bash
cd /Users/pv/code/ortschaft/mobile
flutter test test/providers/auth_provider_test.dart
```
Expected: the auth bootstrap test passes.

- [ ] **Step 6: Commit**

```bash
cd /Users/pv/code/ortschaft
git add mobile/lib/providers mobile/lib/screens/settings_screen.dart mobile/test/providers
git commit -m "feat(mobile): bootstrap auth, home, and search persistence"
```

---

## Phase 4: Map Shell and Preview Routing

### Task 4: Build the default map screen with read-only ratings overlay

**Files:**
- Create: `mobile/lib/widgets/search_bar.dart`
- Create: `mobile/lib/widgets/rating_overlay.dart`
- Create: `mobile/lib/screens/map_screen.dart`

- [ ] **Step 1: Add a simple reusable search bar widget**

Create `mobile/lib/widgets/search_bar.dart`:

```dart
import 'package:flutter/material.dart';

class OrtschaftSearchBar extends StatelessWidget {
  const OrtschaftSearchBar({
    super.key,
    required this.onTap,
    required this.onAvatarTap,
  });

  final VoidCallback onTap;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: onTap,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Text('Search here...'),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              child: IconButton(
                onPressed: onAvatarTap,
                icon: const Icon(Icons.person_outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Implement the ratings overlay adapter**

Create `mobile/lib/widgets/rating_overlay.dart`:

```dart
import 'package:dio/dio.dart';

class RatingOverlayController {
  RatingOverlayController(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> fetchOverlay(String bbox) async {
    final response = await _dio.get('/api/ratings', queryParameters: {'bbox': bbox});
    return Map<String, dynamic>.from(response.data as Map);
  }
}
```

- [ ] **Step 3: Create the map-screen shell**

Create `mobile/lib/screens/map_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/search_bar.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: const Color(0xFFDCE9DD)),
          OrtschaftSearchBar(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
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
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: SizedBox(width: 36, child: Divider(thickness: 4))),
                  SizedBox(height: 12),
                  Text('Home'),
                  Text('Saved places'),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the smoke test again**

```bash
cd /Users/pv/code/ortschaft/mobile
flutter test test/app_smoke_test.dart
```
Expected: it now passes because `MapScreen` renders the `Search here...` shell.

- [ ] **Step 5: Commit**

```bash
cd /Users/pv/code/ortschaft
git add mobile/lib/widgets mobile/lib/screens/map_screen.dart mobile/test/app_smoke_test.dart
git commit -m "feat(mobile): add map screen shell and overlay adapter"
```

---

### Task 5: Add search, route preview, and the Start button

**Files:**
- Create: `mobile/lib/screens/search_screen.dart`
- Create: `mobile/lib/providers/route_provider.dart`
- Create: `mobile/lib/widgets/route_summary.dart`
- Modify: `mobile/lib/models/route_state.dart`
- Create: `mobile/test/providers/route_provider_test.dart`
- Modify: `mobile/lib/screens/map_screen.dart`

- [ ] **Step 1: Write a failing route-provider test**

Create `mobile/test/providers/route_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ortschaft/models/location.dart';
import 'package:ortschaft/models/route_preview.dart';
import 'package:ortschaft/providers/route_provider.dart';

void main() {
  test('setDestination computes a preview when origin already exists', () async {
    final container = ProviderContainer(overrides: [
      routePreviewLoaderProvider.overrideWithValue(
        ({required origin, required destination}) async => RoutePreview(
          geometry: const {'type': 'LineString', 'coordinates': []},
          distance: 3200,
          time: 720,
        ),
      ),
    ]);
    addTearDown(container.dispose);

    await container.read(routeControllerProvider.notifier).setOrigin(
          const Location(id: 'o', name: 'origin', label: 'Origin', lng: 13.4, lat: 52.5),
        );
    await container.read(routeControllerProvider.notifier).setDestination(
          const Location(id: 'd', name: 'destination', label: 'Destination', lng: 13.45, lat: 52.51),
        );

    expect(container.read(routeControllerProvider).preview?.distance, 3200);
  });
}
```

- [ ] **Step 2: Implement route state + controller**

Create `mobile/lib/models/route_state.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

import 'location.dart';
import 'route_preview.dart';

part 'route_state.freezed.dart';

@freezed
class RouteState with _$RouteState {
  const factory RouteState({
    Location? origin,
    Location? destination,
    RoutePreview? preview,
    @Default(false) bool isLoading,
    String? error,
  }) = _RouteState;
}
```

Create `mobile/lib/providers/route_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/location.dart';
import '../models/route_preview.dart';
import '../models/route_state.dart';

typedef RoutePreviewLoader = Future<RoutePreview> Function({
  required Location origin,
  required Location destination,
});

final routePreviewLoaderProvider = Provider<RoutePreviewLoader>((ref) {
  final api = RoutingApi(ref.watch(dioProvider));
  return ({required origin, required destination}) {
    return api.computeRoute(
      [origin.lng, origin.lat],
      [destination.lng, destination.lat],
      ratingWeight: 0.5,
      distanceInfluence: 70,
    );
  };
});

final routeControllerProvider =
    NotifierProvider<RouteController, RouteState>(RouteController.new);

class RouteController extends Notifier<RouteState> {
  @override
  RouteState build() => const RouteState();

  Future<void> setOrigin(Location origin) async {
    state = state.copyWith(origin: origin, error: null);
    await _maybeLoadPreview();
  }

  Future<void> setDestination(Location destination) async {
    state = state.copyWith(destination: destination, error: null);
    await _maybeLoadPreview();
  }

  Future<void> _maybeLoadPreview() async {
    final origin = state.origin;
    final destination = state.destination;
    if (origin == null || destination == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final preview = await ref.read(routePreviewLoaderProvider)(
        origin: origin,
        destination: destination,
      );
      state = state.copyWith(preview: preview, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }
}
```

- [ ] **Step 3: Create the route summary widget and search screen**

Create `mobile/lib/widgets/route_summary.dart`:

```dart
import 'package:flutter/material.dart';

class RouteSummary extends StatelessWidget {
  const RouteSummary({
    super.key,
    required this.durationMinutes,
    required this.distanceKm,
    required this.onStart,
  });

  final int durationMinutes;
  final double distanceKm;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('🚲 $durationMinutes min · ${distanceKm.toStringAsFixed(1)} km'),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: onStart,
          child: const Text('Start'),
        ),
      ],
    );
  }
}
```

Create `mobile/lib/screens/search_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final List<String> _results = <String>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search here...',
            border: InputBorder.none,
          ),
          onSubmitted: (value) {
            setState(() {
              _results
                ..clear()
                ..add('Home · Torstraße 12')
                ..add('Tempelhofer Feld');
            });
          },
        ),
      ),
      body: ListView.builder(
        itemCount: _results.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(_results[index]),
            onTap: () => Navigator.of(context).pop(_results[index]),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Wire the route summary into `MapScreen`**

Update `mobile/lib/screens/map_screen.dart` so the bottom sheet shows the preview summary when `routeControllerProvider.preview` is non-null:

```dart
          Align(
            alignment: Alignment.bottomCenter,
            child: Consumer(
              builder: (context, ref, _) {
                final routeState = ref.watch(routeControllerProvider);
                final preview = routeState.preview;

                return Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: preview == null
                      ? const Text('Home\nSaved places')
                      : RouteSummary(
                          durationMinutes: (preview.time / 60).round(),
                          distanceKm: preview.distance / 1000,
                          onStart: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const NavigationScreen(),
                            ),
                          ),
                        ),
                );
              },
            ),
          ),
```

- [ ] **Step 5: Run route-provider tests**

```bash
cd /Users/pv/code/ortschaft/mobile
dart run build_runner build --delete-conflicting-outputs
flutter test test/providers/route_provider_test.dart
```
Expected: the provider test passes.

- [ ] **Step 6: Commit**

```bash
cd /Users/pv/code/ortschaft
git add mobile/lib/models/route_state.dart \
  mobile/lib/providers/route_provider.dart \
  mobile/lib/widgets/route_summary.dart \
  mobile/lib/screens/search_screen.dart \
  mobile/lib/screens/map_screen.dart \
  mobile/test/providers/route_provider_test.dart
git commit -m "feat(mobile): add search and route preview flow"
```

---

## Phase 5: Live Navigation

### Task 6: Implement the navigation orchestration service around `ferrostar_flutter`

**Files:**
- Create: `mobile/lib/navigation/navigation_service.dart`
- Create: `mobile/lib/providers/navigation_provider.dart`
- Create: `mobile/test/navigation/navigation_service_test.dart`

- [ ] **Step 1: Write the reroute test first**

Create `mobile/test/navigation/navigation_service_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:ortschaft/navigation/navigation_service.dart';

void main() {
  test('reroutes by calling replaceRoute when deviation stream emits', () async {
    final fakeController = FakeFerrostarController();
    final service = NavigationService(
      createController: (_) async => fakeController,
      loadNavigationRoute: ({required origin, required destination}) async => {
        'routes': [
          {'distance': 1234}
        ]
      },
      locationStream: const Stream.empty(),
      speakInstruction: (_) async {},
    );

    await service.start(
      origin: const WaypointInput(lat: 52.52, lng: 13.405),
      destination: const WaypointInput(lat: 52.51, lng: 13.45),
    );

    fakeController.emitDeviation(
      RouteDeviation(
        deviationM: 87,
        durationOffRouteMs: 12000,
        userLocation: const UserLocation(
          lat: 52.521,
          lng: 13.406,
          horizontalAccuracyM: 5,
          timestampMs: 1,
        ),
      ),
    );

    await pumpEventQueue();
    expect(fakeController.replaceRouteCalls, 1);
  });
}
```

- [ ] **Step 2: Implement `NavigationService`**

Create `mobile/lib/navigation/navigation_service.dart`:

```dart
import 'dart:async';

import 'package:ferrostar_flutter/ferrostar_flutter.dart';

typedef CreateController = Future<FerrostarController> Function(
  Map<String, dynamic> osrmJson,
);
typedef LoadNavigationRoute = Future<Map<String, dynamic>> Function({
  required List<double> origin,
  required List<double> destination,
});
typedef SpeakInstruction = Future<void> Function(String text);

class NavigationService {
  NavigationService({
    required this.createController,
    required this.loadNavigationRoute,
    required this.locationStream,
    required this.speakInstruction,
  });

  final CreateController createController;
  final LoadNavigationRoute loadNavigationRoute;
  final Stream<UserLocation> locationStream;
  final SpeakInstruction speakInstruction;

  FerrostarController? _controller;
  StreamSubscription<UserLocation>? _locationSub;
  StreamSubscription<SpokenInstruction>? _spokenSub;
  StreamSubscription<RouteDeviation>? _deviationSub;
  WaypointInput? _destination;

  Future<void> start({
    required WaypointInput origin,
    required WaypointInput destination,
  }) async {
    _destination = destination;
    final routeJson = await loadNavigationRoute(
      origin: [origin.lng, origin.lat],
      destination: [destination.lng, destination.lat],
    );
    _controller = await createController(routeJson);

    _spokenSub = _controller!.spokenInstructionStream.listen(
      (instruction) => speakInstruction(instruction.text),
    );

    _deviationSub = _controller!.deviationStream.listen((deviation) async {
      final dest = _destination;
      if (dest == null) return;

      final rerouteJson = await loadNavigationRoute(
        origin: [deviation.userLocation.lng, deviation.userLocation.lat],
        destination: [dest.lng, dest.lat],
      );
      await _controller!.replaceRoute(osrmJson: rerouteJson);
    });

    _locationSub = locationStream.listen(
      (location) => _controller!.updateLocation(location),
    );
  }

  Future<void> dispose() async {
    await _locationSub?.cancel();
    await _spokenSub?.cancel();
    await _deviationSub?.cancel();
    await _controller?.dispose();
  }
}
```

- [ ] **Step 3: Expose the service through a provider**

Create `mobile/lib/providers/navigation_provider.dart` with providers for `RoutingApi`, `FlutterTts`, `Geolocator.getPositionStream()`, and a `navigationServiceProvider`.

- [ ] **Step 4: Run the service test**

```bash
cd /Users/pv/code/ortschaft/mobile
flutter test test/navigation/navigation_service_test.dart
```
Expected: the reroute test passes.

- [ ] **Step 5: Commit**

```bash
cd /Users/pv/code/ortschaft
git add mobile/lib/navigation mobile/lib/providers/navigation_provider.dart mobile/test/navigation/navigation_service_test.dart
git commit -m "feat(mobile): add ferrostar-backed navigation service"
```

---

### Task 7: Build the navigation screen, banner UI, and camera follow mode

**Files:**
- Create: `mobile/lib/navigation/camera_controller.dart`
- Create: `mobile/lib/screens/navigation_screen.dart`
- Create: `mobile/lib/widgets/turn_banner.dart`
- Create: `mobile/test/navigation/camera_controller_test.dart`
- Modify: `mobile/lib/screens/map_screen.dart`

- [ ] **Step 1: Write the camera follow-mode test**

Create `mobile/test/navigation/camera_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ortschaft/navigation/camera_controller.dart';

void main() {
  test('disables follow mode when user pans', () {
    final controller = NavigationCameraController();
    expect(controller.followMode, isTrue);

    controller.onUserPan();
    expect(controller.followMode, isFalse);

    controller.recenter();
    expect(controller.followMode, isTrue);
  });
}
```

- [ ] **Step 2: Implement the camera helper and turn banner**

Create `mobile/lib/navigation/camera_controller.dart`:

```dart
class NavigationCameraController {
  bool followMode = true;

  void onUserPan() {
    followMode = false;
  }

  void recenter() {
    followMode = true;
  }
}
```

Create `mobile/lib/widgets/turn_banner.dart`:

```dart
import 'package:flutter/material.dart';

class TurnBanner extends StatelessWidget {
  const TurnBanner({
    super.key,
    required this.primaryText,
    required this.distanceText,
  });

  final String primaryText;
  final String distanceText;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2F8F56),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.turn_left, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              primaryText,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          Text(distanceText, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Implement the navigation screen**

Create `mobile/lib/screens/navigation_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/turn_banner.dart';

class NavigationScreen extends ConsumerWidget {
  const NavigationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: const Color(0xFFCFE3D3)),
          const Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: TurnBanner(
                primaryText: 'Turn left onto Kastanienallee',
                distanceText: '200 m',
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('12:34 arrival · 10 min'),
                  Row(
                    children: [
                      Icon(Icons.volume_up_outlined),
                      SizedBox(width: 16),
                      Icon(Icons.close),
                    ],
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

- [ ] **Step 4: Launch navigation from the preview Start button**

Update the `onStart` callback in `mobile/lib/screens/map_screen.dart`:

```dart
onStart: () {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const NavigationScreen()),
  );
},
```

- [ ] **Step 5: Run the camera test**

```bash
cd /Users/pv/code/ortschaft/mobile
flutter test test/navigation/camera_controller_test.dart
```

- [ ] **Step 6: Commit**

```bash
cd /Users/pv/code/ortschaft
git add mobile/lib/navigation/camera_controller.dart \
  mobile/lib/screens/navigation_screen.dart \
  mobile/lib/widgets/turn_banner.dart \
  mobile/lib/screens/map_screen.dart \
  mobile/test/navigation/camera_controller_test.dart
git commit -m "feat(mobile): add navigation screen and camera follow state"
```

---

## Phase 6: Verification and Manual QA

### Task 8: Run the mobile happy-path checks before declaring v0.1 usable

**Files:** none required unless a failure forces code changes

- [ ] **Step 1: Run the whole Flutter test suite**

```bash
cd /Users/pv/code/ortschaft/mobile
flutter test
```
Expected: all tests pass.

- [ ] **Step 2: Run the app against the local stack on iOS simulator**

```bash
cd /Users/pv/code/ortschaft/mobile
flutter run -d ios \
  --dart-define=ORTSCHAFT_API_BASE_URL=http://127.0.0.1:3000 \
  --dart-define=ORTSCHAFT_TILE_STYLE_URL=http://127.0.0.1:8080/tiles/assets/styles/colorful/style.json
```

- [ ] **Step 3: Verify the manual flows**

Check these in order:

```text
1. First launch silently creates an anonymous session.
2. Search opens full-screen and selecting a result returns to the map.
3. Route preview renders distance/time and Start button.
4. Start enters navigation screen and turn banner updates as location updates arrive.
5. Settings screen shows guest/account state and saved home label.
```

- [ ] **Step 4: Commit only after the manual flow works**

```bash
cd /Users/pv/code/ortschaft
git status --short
```
Expected: clean if no fixes were needed. If you had to patch issues during the smoke run, commit them with focused messages before ending the plan.

---

## Self-Review Notes

- **Spec coverage:** This plan covers auth bootstrap, search, route preview via `POST /api/route`, settings/home flows, read-only ratings overlay, navigation entry, turn banner UI, rerouting orchestration, mute/close affordances, and the thin-client architecture described in the spec.
- **Explicit omissions preserved:** The plan does not add painting, background navigation, offline downloads, or preference sliders, matching the spec's out-of-scope list.
- **Dependency boundary is clear:** The mobile app does not parse GraphHopper navigation JSON itself. It treats `/api/navigate` as an opaque Mapbox Directions payload and hands it to `ferrostar_flutter`, exactly as Plan A and Plan B require.

## After This Plan

If Tasks 1-8 are complete, the repo has all three deliverables from the spec: plugin, backend navigation endpoint, and the mobile app shell that consumes both. The next decision is whether to finish by merging all three plans sequentially or to execute Plan B in parallel while Plan A is still stabilizing.
