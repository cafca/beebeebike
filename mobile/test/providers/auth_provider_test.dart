import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:beebeebike/api/client.dart';
import 'package:beebeebike/providers/auth_provider.dart';

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
        'display_name': '',
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
