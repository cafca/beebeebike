import 'package:beebeebike/api/client.dart';
import 'package:beebeebike/app.dart';
import 'package:beebeebike/config/app_config.dart';
import 'package:beebeebike/models/location.dart';
import 'package:beebeebike/models/route_preview.dart';
import 'package:beebeebike/models/user.dart';
import 'package:beebeebike/providers/auth_provider.dart';
import 'package:beebeebike/providers/search_history_provider.dart';
import 'package:beebeebike/services/map_style_loader.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SyncAuthController extends AuthController {
  _SyncAuthController({required this.authenticated});
  final bool authenticated;

  @override
  Future<User?> build() async => authenticated
      ? const User(
          id: 'user-1',
          email: 'test@example.com',
          displayName: 'Test User',
          accountType: 'registered',
        )
      : const User(id: 'anon-test', accountType: 'anonymous');
}

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
    'account_type': 'registered',
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
    // GraphHopper returns time in milliseconds. 1200000 ms = 20 min.
    'time': 1200000.0,
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

      if (path == '/api/auth/register') {
        if (loginSucceeds) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: TestFixtures.loggedInUser,
          ));
        } else {
          handler.reject(DioException(
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: 409,
                data: {'error': 'email already taken'}),
            type: DioExceptionType.badResponse,
          ));
        }
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

      if (path == '/api/navigate') {
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
        if (options.method == 'GET') {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 404,
          ));
        } else if (options.method == 'PUT') {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'id': 'home',
              'label': options.data?['label'] ?? 'Home',
              'lng': options.data?['lng'] ?? 13.4050,
              'lat': options.data?['lat'] ?? 52.5200,
            },
          ));
        } else if (options.method == 'DELETE') {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
          ));
        } else {
          handler.next(options);
        }
        return;
      }

      handler.next(options);
    },
  ));
  return dio;
}

List<Override> testProviderOverrides({
  required SharedPreferences prefs,
  bool authenticated = false,
  bool geocodeReturnsResults = true,
  bool routeSucceeds = true,
  bool loginSucceeds = true,
}) {
  return [
    appConfigProvider.overrideWithValue(const AppConfig(
      apiBaseUrl: 'http://localhost:3000',
      tileServerBaseUrl: 'http://localhost:8080',
      tileStyleUrl: 'http://localhost:8080/tiles/assets/styles/colorful/style.json',
    )),
    mapStyleProvider.overrideWith((ref) => Future.value('{}')),
    dioProvider.overrideWithValue(buildMockDio(
      authenticated: authenticated,
      geocodeReturnsResults: geocodeReturnsResults,
      routeSucceeds: routeSucceeds,
      loginSucceeds: loginSucceeds,
    )),
    authControllerProvider.overrideWith(
      () => _SyncAuthController(authenticated: authenticated),
    ),
    sharedPreferencesProvider.overrideWithValue(prefs),
  ];
}

/// Convenience helper for widget tests.
///
/// Usage:
/// ```dart
/// SharedPreferences.setMockInitialValues({});
/// final prefs = await SharedPreferences.getInstance();
/// await tester.pumpWidget(buildTestWidget(MyWidget(), prefs: prefs));
/// ```
Widget buildTestWidget(
  Widget child, {
  required SharedPreferences prefs,
  bool authenticated = false,
  bool geocodeReturnsResults = true,
  bool routeSucceeds = true,
  bool loginSucceeds = true,
}) {
  return ProviderScope(
    overrides: testProviderOverrides(
      prefs: prefs,
      authenticated: authenticated,
      geocodeReturnsResults: geocodeReturnsResults,
      routeSucceeds: routeSucceeds,
      loginSucceeds: loginSucceeds,
    ),
    child: MaterialApp(home: child),
  );
}
