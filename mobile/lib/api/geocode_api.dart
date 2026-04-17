import 'package:dio/dio.dart';

import '../models/geocode_result.dart';

class GeocodeApi {
  GeocodeApi(this._dio);

  final Dio _dio;

  Future<List<GeocodeResult>> search(String query) async {
    final response = await _dio.get('/api/geocode', queryParameters: {'q': query});
    final features = (response.data['features'] as List).cast<Map<String, dynamic>>();
    return features.map((f) {
      final props = f['properties'] as Map<String, dynamic>;
      final coords = (f['geometry']?['coordinates'] as List?) ?? [0.0, 0.0];
      return GeocodeResult(
        id: '${props['osm_type'] ?? 'U'}:${props['osm_id'] ?? '0'}',
        name: (props['name'] as String?) ?? '',
        label: (props['label'] as String?) ?? (props['name'] as String?) ?? '',
        lng: (coords[0] as num).toDouble(),
        lat: (coords[1] as num).toDouble(),
      );
    }).toList();
  }
}
