import 'package:dio/dio.dart';

import '../models/route_preview.dart';

class RoutingApi {
  RoutingApi(this._dio);

  final Dio _dio;

  Future<RoutePreview> computeRoute(
    List<double> origin,
    List<double> destination, {
    double? ratingWeight,
    double? distanceInfluence,
  }) async {
    final response = await _dio.post('/api/route', data: {
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
    final response = await _dio.post('/api/navigate', data: {
      'origin': origin,
      'destination': destination,
      if (ratingWeight != null) 'rating_weight': ratingWeight,
      if (distanceInfluence != null) 'distance_influence': distanceInfluence,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }
}
