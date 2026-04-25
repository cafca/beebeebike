import 'package:ferrostar_flutter/src/models/spoken_instruction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SpokenInstruction round-trips with ssml', () {
    final json = {
      'uuid': 'a3f1',
      'text': 'In 200 meters, turn left onto Kastanienallee',
      'ssml': '<speak>In 200 meters, turn left</speak>',
      'trigger_distance_m': 200.0,
      'emitted_at_ms': 1744800000000,
    };
    final s = SpokenInstruction.fromJson(json);
    expect(s.uuid, 'a3f1');
    expect(s.text, startsWith('In 200'));
    expect(s.ssml, isNotNull);
    expect(s.toJson(), json);
  });

  test('SpokenInstruction round-trips with null ssml', () {
    final s = SpokenInstruction.fromJson({
      'uuid': 'a3f1',
      'text': 'Continue',
      'ssml': null,
      'trigger_distance_m': 500.0,
      'emitted_at_ms': 1,
    });
    expect(s.ssml, isNull);
  });
}
