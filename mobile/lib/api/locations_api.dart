import 'package:beebeebike/models/location.dart';
import 'package:dio/dio.dart';

class LocationsApi {
  LocationsApi(this._dio);

  final Dio _dio;

  Future<Location?> getHome() async {
    try {
      final response = await _dio.get<dynamic>('/api/locations/home');
      final data = response.data;
      if (data == null) return null;
      return Location.fromJson(Map<String, dynamic>.from(data as Map));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Location> setHome(Location location) async {
    final response = await _dio.put<dynamic>('/api/locations/home', data: <String, dynamic>{
      'label': location.label,
      'lng': location.lng,
      'lat': location.lat,
    });
    return Location.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<void> deleteHome() async {
    await _dio.delete<dynamic>('/api/locations/home');
  }
}
