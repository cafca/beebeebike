import 'package:dio/dio.dart';

class RatingOverlayController {
  RatingOverlayController(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> fetchOverlay(String bbox) async {
    final response = await _dio.get('/api/ratings', queryParameters: {'bbox': bbox});
    return Map<String, dynamic>.from(response.data as Map);
  }
}
