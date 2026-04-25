import 'package:beebeebike/api/ratings_paint_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late RatingsPaintApi api;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    adapter = DioAdapter(dio: dio);
    api = RatingsPaintApi(dio);
  });

  const polygon = {
    'type': 'Polygon',
    'coordinates': [
      [
        [13.4, 52.5],
        [13.41, 52.5],
        [13.41, 52.51],
        [13.4, 52.51],
        [13.4, 52.5],
      ]
    ],
  };

  test('paint PUTs geometry + value + target_id', () async {
    adapter.onPut(
      '/api/ratings/paint',
      (request) => request.reply(200, {
        'created_id': 7,
        'clipped_count': 0,
        'deleted_count': 0,
        'can_undo': true,
        'can_redo': false,
      }),
      data: {'geometry': polygon, 'value': 3, 'target_id': null},
    );
    final r = await api.paint(geometry: polygon, value: 3);
    expect(r.createdId, 7);
    expect(r.canUndo, isTrue);
  });

  test('paint with target_id sends it in body', () async {
    adapter.onPut(
      '/api/ratings/paint',
      (request) => request.reply(200, {
        'created_id': null,
        'clipped_count': 0,
        'deleted_count': 1,
        'can_undo': true,
        'can_redo': false,
      }),
      data: {'geometry': polygon, 'value': 0, 'target_id': 11},
    );
    final r = await api.paint(geometry: polygon, value: 0, targetId: 11);
    expect(r.deletedCount, 1);
  });

  test('undo POSTs and parses response', () async {
    adapter.onPost(
      '/api/ratings/undo',
      (request) => request.reply(200, {
        'created_id': null,
        'clipped_count': 0,
        'deleted_count': 0,
        'can_undo': false,
        'can_redo': true,
      }),
    );
    final r = await api.undo();
    expect(r.canUndo, isFalse);
    expect(r.canRedo, isTrue);
  });

  test('redo POSTs and parses response', () async {
    adapter.onPost(
      '/api/ratings/redo',
      (request) => request.reply(200, {
        'created_id': null,
        'clipped_count': 0,
        'deleted_count': 0,
        'can_undo': true,
        'can_redo': false,
      }),
    );
    final r = await api.redo();
    expect(r.canUndo, isTrue);
  });
}
