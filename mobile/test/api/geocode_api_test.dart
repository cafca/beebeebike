import 'package:beebeebike/api/geocode_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late GeocodeApi api;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
    adapter = DioAdapter(dio: dio);
    api = GeocodeApi(dio);
  });

  test('uses name field for named places', () async {
    adapter.onGet('/api/geocode', (server) {
      server.reply(200, {
        'features': [
          {
            'geometry': {'coordinates': [13.4050, 52.5200]},
            'properties': {
              'osm_type': 'N',
              'osm_id': '42',
              'name': 'Alexanderplatz',
              'district': 'Mitte',
              'osm_value': 'station',
            },
          },
        ],
      });
    }, queryParameters: {'q': 'Alex'});

    final results = await api.search('Alex');
    expect(results.first.name, 'Alexanderplatz');
    expect(results.first.label, 'Mitte · station');
  });

  test('builds name from street + housenumber when name is empty', () async {
    adapter.onGet('/api/geocode', (server) {
      server.reply(200, {
        'features': [
          {
            'geometry': {'coordinates': [13.4333, 52.4833]},
            'properties': {
              'osm_type': 'W',
              'osm_id': '99',
              'name': '',
              'street': 'Leinestraße',
              'housenumber': '9',
              'district': 'Neukölln',
              'osm_value': 'house',
            },
          },
        ],
      });
    }, queryParameters: {'q': 'leine 9'});

    final results = await api.search('leine 9');
    expect(results.first.name, 'Leinestraße 9');
    expect(results.first.label, contains('Neukölln'));
  });

  test('uses street alone when housenumber absent', () async {
    adapter.onGet('/api/geocode', (server) {
      server.reply(200, {
        'features': [
          {
            'geometry': {'coordinates': [13.4333, 52.4833]},
            'properties': {
              'osm_type': 'W',
              'osm_id': '100',
              'name': '',
              'street': 'Leinestraße',
              'district': 'Neukölln',
              'osm_value': 'residential',
            },
          },
        ],
      });
    }, queryParameters: {'q': 'leine'});

    final results = await api.search('leine');
    expect(results.first.name, 'Leinestraße');
  });
}
