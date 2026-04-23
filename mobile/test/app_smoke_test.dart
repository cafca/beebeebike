import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beebeebike/app.dart';
import 'package:beebeebike/api/client.dart';
import 'package:beebeebike/config/app_config.dart';
import 'package:beebeebike/providers/onboarding_provider.dart';
import 'package:beebeebike/providers/search_history_provider.dart';
import 'package:beebeebike/services/map_style_loader.dart';
import 'package:dio/dio.dart';

void main() {
  testWidgets('boots to the map screen shell', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding.completed.v1': true});
    final prefs = await SharedPreferences.getInstance();

    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/api/auth/me') {
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
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'http://localhost:3000',
              tileServerBaseUrl: 'http://localhost:8080',
              tileStyleUrl: 'http://localhost:8080/tiles/assets/styles/colorful/style.json',
              ratingsSseEnabled: false,
            ),
          ),
          mapStyleProvider.overrideWith((ref) => Future.value('{}')),
          dioProvider.overrideWithValue(dio),
          sharedPreferencesProvider.overrideWithValue(prefs),
          onboardingCompletedProvider
              .overrideWith(() => _AlwaysDoneOnboarding()),
        ],
        child: const BeeBeeBikeApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Where to?'), findsOneWidget);
  });

  testWidgets('auth provider begins initialising on startup', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding.completed.v1': true});
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
            tileServerBaseUrl: 'http://localhost:8080',
            tileStyleUrl: 'http://localhost:8080/tiles/style.json',
            ratingsSseEnabled: false,
          )),
          mapStyleProvider.overrideWith((ref) => Future.value('{}')),
          dioProvider.overrideWithValue(dio),
          sharedPreferencesProvider.overrideWithValue(prefs),
          onboardingCompletedProvider
              .overrideWith(() => _AlwaysDoneOnboarding()),
        ],
        child: const BeeBeeBikeApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(authMeCallCount, equals(1),
        reason: 'authControllerProvider must be initialised on app startup');
  });
}

class _AlwaysDoneOnboarding extends OnboardingController {
  @override
  bool build() => true;
}
