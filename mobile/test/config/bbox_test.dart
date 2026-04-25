import 'package:beebeebike/config/berlin_bounds.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const berlin = Bbox(west: 13.0, south: 52.3, east: 13.8, north: 52.7);

  group('Bbox.contains', () {
    test('inside returns true', () {
      expect(berlin.contains(52.516, 13.378), isTrue); // Brandenburg Gate
    });

    test('on edge returns true', () {
      expect(berlin.contains(52.3, 13.0), isTrue);
      expect(berlin.contains(52.7, 13.8), isTrue);
    });

    test('north of bbox returns false', () {
      expect(berlin.contains(53.0, 13.4), isFalse);
    });

    test('south of bbox returns false', () {
      expect(berlin.contains(52.0, 13.4), isFalse);
    });

    test('east of bbox returns false', () {
      expect(berlin.contains(52.5, 14.0), isFalse);
    });

    test('west of bbox returns false', () {
      expect(berlin.contains(52.5, 12.5), isFalse);
    });

    test('Munich is outside Berlin bbox', () {
      expect(berlin.contains(48.137, 11.575), isFalse);
    });
  });

  group('Bbox JSON', () {
    test('round trips', () {
      final json = berlin.toJson();
      expect(Bbox.fromJson(json), equals(berlin));
    });

    test('parses integer-typed JSON values', () {
      final b = Bbox.fromJson(<String, dynamic>{
        'west': 13,
        'south': 52,
        'east': 14,
        'north': 53,
      });
      expect(b.west, 13.0);
      expect(b.north, 53.0);
    });
  });
}
