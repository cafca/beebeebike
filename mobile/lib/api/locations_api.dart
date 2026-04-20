import 'package:dio/dio.dart';

import '../models/location.dart';

class LocationsApi {
  LocationsApi(this._dio);

  final Dio _dio;

  Future<Location?> getHome() async {
    try {
      final response = await _dio.get('/api/locations/home');
      final data = response.data;
      if (data == null) return null;
      return Location.fromJson(Map<String, dynamic>.from(data as Map));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
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
