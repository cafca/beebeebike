import 'package:beebeebike/models/paint_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses backend JSON with created_id and clipping counts', () {
    final json = {
      'created_id': 42,
      'clipped_count': 1,
      'deleted_count': 0,
      'can_undo': true,
      'can_redo': false,
    };
    final r = PaintResponse.fromJson(json);
    expect(r.createdId, 42);
    expect(r.clippedCount, 1);
    expect(r.deletedCount, 0);
    expect(r.canUndo, isTrue);
    expect(r.canRedo, isFalse);
  });

  test('parses null created_id (eraser response)', () {
    final r = PaintResponse.fromJson({
      'created_id': null,
      'clipped_count': 0,
      'deleted_count': 2,
      'can_undo': true,
      'can_redo': true,
    });
    expect(r.createdId, isNull);
    expect(r.deletedCount, 2);
  });
}
