import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:beebeebike/services/brush_geometry.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  group('metersPerPixel', () {
    test('roughly matches known values at equator z=14', () {
      final mpp = BrushGeometry.metersPerPixel(lat: 0, zoom: 14);
      expect(mpp, closeTo(4.777, 0.01));
    });

    test('shrinks with latitude (Berlin)', () {
      final mppEq = BrushGeometry.metersPerPixel(lat: 0, zoom: 14);
      final mppBer = BrushGeometry.metersPerPixel(lat: 52.5, zoom: 14);
      expect(mppBer, lessThan(mppEq));
      expect(mppBer / mppEq, closeTo(math.cos(52.5 * math.pi / 180), 0.001));
    });
  });

  group('shouldSample', () {
    test('true when >= 4px', () {
      expect(BrushGeometry.shouldSample(Offset.zero, const Offset(4, 0)), isTrue);
      expect(BrushGeometry.shouldSample(Offset.zero, const Offset(0, 5)), isTrue);
    });
    test('false when < 4px', () {
      expect(BrushGeometry.shouldSample(Offset.zero, const Offset(3, 0)), isFalse);
      expect(BrushGeometry.shouldSample(Offset.zero, const Offset(2, 2)), isFalse);
    });
  });

  group('buildPolygon', () {
    test('returns null for < 2 points', () {
      expect(
        BrushGeometry.buildPolygon(
          points: const [LatLng(52.5, 13.4)],
          zoom: 14,
        ),
        isNull,
      );
    });

    test('builds closed Polygon with positive area for 3-point stroke', () {
      final geom = BrushGeometry.buildPolygon(
        points: const [
          LatLng(52.5, 13.400),
          LatLng(52.5, 13.401),
          LatLng(52.5, 13.402),
        ],
        zoom: 14,
      );
      expect(geom, isNotNull);
      expect(geom!['type'], 'Polygon');
      final coords = (geom['coordinates'] as List).first as List;
      expect(coords.length, greaterThanOrEqualTo(8));
      final first = coords.first as List;
      final last = coords.last as List;
      expect(first[0], last[0]);
      expect(first[1], last[1]);
    });

    test('enforces 5m minimum radius at high zoom', () {
      final geom = BrushGeometry.buildPolygon(
        points: const [LatLng(52.5, 13.4), LatLng(52.5, 13.40001)],
        zoom: 20,
      );
      expect(geom, isNotNull);
    });

    test('polygon winding: signed area non-zero (CW orientation)', () {
      final geom = BrushGeometry.buildPolygon(
        points: const [
          LatLng(52.5, 13.400),
          LatLng(52.5, 13.401),
          LatLng(52.501, 13.401),
          LatLng(52.501, 13.400),
        ],
        zoom: 14,
      );
      expect(geom, isNotNull);
      final coords = (geom!['coordinates'] as List).first as List;
      expect(coords.length, greaterThanOrEqualTo(4));

      // Calculate signed area using shoelace formula
      final signedArea = _signedArea(coords);
      // Verify polygon has non-zero area (not degenerate)
      expect(signedArea, isNot(0));
      // TODO: Currently the ring is oriented CW (signedArea < 0).
      // Once GeoJSON right-hand-rule enforcement is needed, update the ring
      // orientation in buildPolygon to produce CCW rings (signedArea > 0).
      // Observed sign: negative (CW), magnitude ~-0.0000026 for test case.
      expect(signedArea, lessThan(0));
    });

    test('returns null for all-equal points (degenerate dedupe)', () {
      final geom = BrushGeometry.buildPolygon(
        points: const [
          LatLng(52.5, 13.400),
          LatLng(52.5, 13.400),
          LatLng(52.5, 13.400),
          LatLng(52.5, 13.400),
          LatLng(52.5, 13.400),
        ],
        zoom: 14,
      );
      expect(geom, isNull);
    });

    test('produces valid polygon for U-turn stroke (3-point A→B→A)', () {
      final geom = BrushGeometry.buildPolygon(
        points: const [
          LatLng(52.5, 13.400),
          LatLng(52.5, 13.401),
          LatLng(52.5, 13.400),
        ],
        zoom: 14,
      );
      expect(geom, isNotNull);
      expect(geom!['type'], 'Polygon');
      final coords = (geom['coordinates'] as List).first as List;
      // U-turn should still produce a valid closed ring (not collapse to null)
      expect(coords.length, greaterThanOrEqualTo(4));
      final first = coords.first as List;
      final last = coords.last as List;
      expect(first[0], last[0]);
      expect(first[1], last[1]);
    });
  });
}

/// Calculate signed area of a polygon ring using the shoelace formula.
/// Positive area = CCW (per GeoJSON right-hand rule for exterior rings).
/// Negative area = CW.
/// Parameters: coords is a list of [lng, lat] pairs.
double _signedArea(List coords) {
  double s = 0;
  for (var i = 0; i < coords.length - 1; i++) {
    final a = coords[i] as List;
    final b = coords[i + 1] as List;
    s += (a[0] as num) * (b[1] as num) - (b[0] as num) * (a[1] as num);
  }
  return s / 2;
}
