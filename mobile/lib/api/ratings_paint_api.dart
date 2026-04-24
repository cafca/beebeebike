import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/paint_response.dart';
import 'client.dart';

class RatingsPaintApi {
  RatingsPaintApi(this._dio);

  final Dio _dio;

  Future<PaintResponse> paint({
    required Map<String, dynamic> geometry,
    required int value,
    int? targetId,
  }) async {
    final response = await _dio.put(
      '/api/ratings/paint',
      data: {
        'geometry': geometry,
        'value': value,
        'target_id': targetId,
      },
    );
    return PaintResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<PaintResponse> undo() async {
    final response = await _dio.post('/api/ratings/undo');
    return PaintResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<PaintResponse> redo() async {
    final response = await _dio.post('/api/ratings/redo');
    return PaintResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}

final ratingsPaintApiProvider =
    Provider<RatingsPaintApi>((ref) => RatingsPaintApi(ref.watch(dioProvider)));
