import 'package:beebeebike/api/client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RatingsApi {
  RatingsApi(this._dio);

  final Dio _dio;

  /// Fetch the rating overlay FeatureCollection for the given bbox.
  ///
  /// [bbox] must be `west,south,east,north` in EPSG:4326 degrees. The caller
  /// may pass a [cancelToken] so the request can be cancelled when the camera
  /// moves again before the previous fetch completes.
  Future<Map<String, dynamic>> getOverlay(
    String bbox, {
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<dynamic>(
      '/api/ratings',
      queryParameters: <String, dynamic>{'bbox': bbox},
      cancelToken: cancelToken,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}

final ratingsApiProvider =
    Provider<RatingsApi>((ref) => RatingsApi(ref.watch(dioProvider)));
