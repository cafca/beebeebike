import 'package:dio/dio.dart';

import '../models/geocode_result.dart';

class GeocodeApi {
  GeocodeApi(this._dio);

  final Dio _dio;

  Future<List<GeocodeResult>> search(String query) async {
    final response = await _dio.get('/api/geocode', queryParameters: {'q': query});
    final features = (response.data['features'] as List).cast<Map<String, dynamic>>();
    return features.map(GeocodeResult.fromJson).toList();
  }
}
