import 'package:beebeebike/api/client.dart';
import 'package:beebeebike/app.dart';
import 'package:beebeebike/providers/brush_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('paint FAB flips paint mode and shows PaintSheet',
      (tester) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    DioAdapter(dio: dio)
      ..onGet('/api/auth/me', (r) => r.reply(401, <String, dynamic>{}))
      ..onPost('/api/auth/anonymous',
          (r) => r.reply(200, {'id': 'anon', 'account_type': 'anonymous'}))
      ..onGet('/api/ratings',
          (r) => r.reply(200, {'type': 'FeatureCollection', 'features': <dynamic>[]}));

    await tester.pumpWidget(ProviderScope(
      overrides: [dioProvider.overrideWithValue(dio)],
      child: const BeeBeeBikeApp(),
    ));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final fab = find.byKey(const ValueKey('paint-fab'));
    expect(fab, findsOneWidget);
    await tester.tap(fab);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final state = container.read(brushControllerProvider);
    expect(state.paintMode, isTrue);
    expect(state.value, 1);

    expect(find.byKey(const ValueKey('paint-toggle')), findsOneWidget);
    for (final v in const [-7, -3, -1, 0, 1, 3, 7]) {
      expect(find.byKey(ValueKey('paint-chip-$v')), findsOneWidget);
    }
  });
}
