import 'package:beebeebike/models/route_preview.dart';
import 'package:dio/dio.dart';

class RoutingApi {
  RoutingApi(this._dio);

  final Dio _dio;

  Future<RoutePreview> computeRoute(
    List<double> origin,
    List<double> destination, {
    double? ratingWeight,
    double? distanceInfluence,
  }) async {
    final response = await _dio.post<dynamic>('/api/route', data: <String, dynamic>{
      'origin': origin,
      'destination': destination,
      if (ratingWeight != null) 'rating_weight': ratingWeight,
      if (distanceInfluence != null) 'distance_influence': distanceInfluence,
    });
    return RoutePreview.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> computeNavigationRoute(
    List<double> origin,
    List<double> destination, {
    double? ratingWeight,
    double? distanceInfluence,
  }) async {
    final response = await _dio.post<dynamic>('/api/navigate', data: <String, dynamic>{
      'origin': origin,
      'destination': destination,
      if (ratingWeight != null) 'rating_weight': ratingWeight,
      if (distanceInfluence != null) 'distance_influence': distanceInfluence,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }
}
