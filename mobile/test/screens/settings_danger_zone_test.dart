import 'package:beebeebike/api/client.dart';
import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/screens/settings_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpTall(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('danger zone hidden when anonymous', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      buildTestWidget(
        const SettingsScreen(),
        prefs: prefs,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.settingsDeleteAccount), findsNothing);
  });

  testWidgets('danger zone visible when registered', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      buildTestWidget(
        const SettingsScreen(),
        prefs: prefs,
        authenticated: true,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.settingsDeleteAccount), findsOneWidget);
  });

  testWidgets('confirm dialog cancels do not call delete', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await pumpTall(tester);
    var deleteCalls = 0;
    final dio = _mockDioForDelete(onDelete: () => deleteCalls++);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testProviderOverrides(prefs: prefs, authenticated: true),
          dioProvider.overrideWithValue(dio),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l10n.settingsDeleteAccount));
    await tester.pumpAndSettle();

    expect(find.text(l10n.settingsDeleteConfirmTitle), findsOneWidget);

    await tester.tap(find.text(l10n.settingsDeleteCancel));
    await tester.pumpAndSettle();

    expect(deleteCalls, 0);
    expect(find.text(l10n.settingsDeleteSuccess), findsNothing);
  });

  testWidgets('confirm dialog proceed dispatches delete + snackbar',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await pumpTall(tester);
    var deleteCalls = 0;
    final dio = _mockDioForDelete(onDelete: () => deleteCalls++);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testProviderOverrides(prefs: prefs, authenticated: true),
          dioProvider.overrideWithValue(dio),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l10n.settingsDeleteAccount));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.settingsDeleteConfirm));
    await tester.pumpAndSettle();

    expect(deleteCalls, 1);
    expect(find.text(l10n.settingsDeleteSuccess), findsOneWidget);
  });

  testWidgets('delete failure surfaces error snackbar', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await pumpTall(tester);
    final dio = _mockDioForDelete(fail: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testProviderOverrides(prefs: prefs, authenticated: true),
          dioProvider.overrideWithValue(dio),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l10n.settingsDeleteAccount));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.settingsDeleteConfirm));
    await tester.pumpAndSettle();

    expect(find.textContaining('Delete failed'), findsOneWidget);
  });
}

Dio _mockDioForDelete({void Function()? onDelete, bool fail = false}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      if (options.path == '/api/auth/account' && options.method == 'DELETE') {
        onDelete?.call();
        if (fail) {
          handler.reject(DioException(
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: 500),
            type: DioExceptionType.badResponse,
          ));
        } else {
          handler.resolve(
              Response(requestOptions: options, statusCode: 204));
        }
        return;
      }
      if (options.path == '/api/auth/anonymous') {
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: TestFixtures.anonymousUser,
        ));
        return;
      }
      if (options.path == '/api/auth/me') {
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: TestFixtures.loggedInUser,
        ));
        return;
      }
      handler.next(options);
    },
  ));
  return dio;
}
