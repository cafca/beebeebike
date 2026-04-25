import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:beebeebike/dev/polyline_walker.dart';

void main() {
  group('PolylineWalker', () {
    // ~111 km per degree of latitude. These three points form a 2-leg polyline
    // running due east along the equator, so each leg's bearing is 90.
    final points = [
      const LatLng(0.0, 0.0),
      const LatLng(0.0, 0.001), // ~111 m east
      const LatLng(0.0, 0.003), // ~222 m further east
    ];

    test('totalLengthM ≈ sum of segment lengths', () {
      final w = PolylineWalker(points);
      // Segment 1 ≈ 111.32 m; segment 2 ≈ 222.64 m; total ≈ 333.96 m.
      expect(w.totalLengthM, closeTo(333.96, 1.0));
    });

    test('positionAt(0) returns first point with bearing of first segment', () {
      final w = PolylineWalker(points);
      final p = w.positionAt(0);
      expect(p.latLng.latitude, closeTo(0.0, 1e-9));
      expect(p.latLng.longitude, closeTo(0.0, 1e-9));
      expect(p.bearingDeg, closeTo(90.0, 0.5));
    });

    test('positionAt(totalLength) returns last point', () {
      final w = PolylineWalker(points);
      final p = w.positionAt(w.totalLengthM);
      expect(p.latLng.latitude, closeTo(0.0, 1e-9));
      expect(p.latLng.longitude, closeTo(0.003, 1e-9));
    });

    test('positionAt midpoint of segment 1 interpolates lng', () {
      final w = PolylineWalker(points);
      final p = w.positionAt(55.66); // half of leg 1
      expect(p.latLng.longitude, closeTo(0.0005, 1e-5));
      expect(p.bearingDeg, closeTo(90.0, 0.5));
    });

    test('positionAt clamps below 0 and above totalLength', () {
      final w = PolylineWalker(points);
      expect(w.positionAt(-100).latLng.longitude, closeTo(0.0, 1e-9));
      expect(w.positionAt(99999).latLng.longitude, closeTo(0.003, 1e-9));
    });

    test('throws on polyline with fewer than 2 points', () {
      expect(() => PolylineWalker(const [LatLng(0, 0)]), throwsArgumentError);
    });
  });
}
