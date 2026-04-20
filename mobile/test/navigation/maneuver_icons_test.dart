import 'package:beebeebike/navigation/maneuver_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('iconForManeuver', () {
    test('maps turn left/right variants', () {
      expect(iconForManeuver('turn', 'left'), Icons.turn_left);
      expect(iconForManeuver('turn', 'right'), Icons.turn_right);
      expect(iconForManeuver('turn', 'sharp_left'), Icons.turn_sharp_left);
      expect(iconForManeuver('turn', 'sharp_right'), Icons.turn_sharp_right);
      expect(iconForManeuver('turn', 'slight_left'), Icons.turn_slight_left);
      expect(iconForManeuver('turn', 'slight_right'), Icons.turn_slight_right);
    });

    test('arrive -> flag', () {
      expect(iconForManeuver('arrive', null), Icons.flag);
    });

    test('unknown -> straight', () {
      expect(iconForManeuver('merge', 'left'), Icons.straight);
      expect(iconForManeuver('', null), Icons.straight);
    });
  });

  group('formatDistance', () {
    test('< 1000 m uses meters', () {
      expect(formatDistance(0), '0 m');
      expect(formatDistance(150), '150 m');
      expect(formatDistance(999.4), '999 m');
    });

    test('>= 1000 m uses km with 1 decimal', () {
      expect(formatDistance(1000), '1.0 km');
      expect(formatDistance(1234), '1.2 km');
      expect(formatDistance(15600), '15.6 km');
    });
  });

  group('formatEta', () {
    test('contains arrival time and remaining minutes', () {
      final out = formatEta(360000); // 6 min
      expect(out, contains('arrival'));
      expect(out, contains('6 min'));
    });

    test('zero duration renders 0 min', () {
      expect(formatEta(0), contains('0 min'));
    });
  });
}
