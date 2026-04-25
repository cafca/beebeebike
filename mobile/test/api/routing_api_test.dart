import 'package:beebeebike/api/routing_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

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
      distanceInfluence: 70,
    );

    expect(((json['routes'] as List).first as Map<String, dynamic>)['distance'], 1234.5);
  });
}
