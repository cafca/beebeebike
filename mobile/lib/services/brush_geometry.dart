import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:maplibre_gl/maplibre_gl.dart';

/// Pure sampling + buffering used by `BrushController`. No Flutter widget
/// dependencies and no MapLibre I/O — callers pass in pre-computed screen
/// offsets and latlng samples so this stays unit-testable.
///
/// The Dart `turf` package does not ship a `buffer()` implementation, so
/// we hand-roll a rounded-capsule polyline buffer: offset each segment by
/// `radiusM` to left and right, walk the right side forward, add a
/// semicircular end cap, walk the left side backward, and add a
/// semicircular start cap.
class BrushGeometry {
  BrushGeometry._();

  static const double minMovePx = 4.0;
  static const double brushPx = 30.0;
  static const double minRadiusKm = 0.005;
  static const int _capSegments = 8;

  static double metersPerPixel({required double lat, required double zoom}) {
    return 40075016.686 *
        math.cos(lat * math.pi / 180) /
        math.pow(2, zoom + 9);
  }

  static bool shouldSample(Offset last, Offset next) {
    final dx = next.dx - last.dx;
    final dy = next.dy - last.dy;
    return dx * dx + dy * dy >= minMovePx * minMovePx;
  }

  static Map<String, dynamic>? buildPolygon({
    required List<LatLng> points,
    required double zoom,
  }) {
    if (points.length < 2) return null;
    final avgLat =
        points.fold<double>(0, (s, p) => s + p.latitude) / points.length;
    final mpp = metersPerPixel(lat: avgLat, zoom: zoom);
    final radiusM = math.max(brushPx * mpp, minRadiusKm * 1000);

    final p0 = points.first;
    const mPerDegLat = 111320.0;
    final mPerDegLon = 111320.0 * math.cos(avgLat * math.pi / 180);

    List<double> toXY(LatLng p) => [
          (p.longitude - p0.longitude) * mPerDegLon,
          (p.latitude - p0.latitude) * mPerDegLat,
        ];
    List<double> toLngLat(List<double> xy) => [
          p0.longitude + xy[0] / mPerDegLon,
          p0.latitude + xy[1] / mPerDegLat,
        ];

    final pts = points.map(toXY).toList();

    final unique = <List<double>>[pts.first];
    for (var i = 1; i < pts.length; i++) {
      if (pts[i][0] != unique.last[0] || pts[i][1] != unique.last[1]) {
        unique.add(pts[i]);
      }
    }
    if (unique.length < 2) return null;

    final right = <List<double>>[];
    final left = <List<double>>[];
    for (var i = 0; i < unique.length - 1; i++) {
      final a = unique[i];
      final b = unique[i + 1];
      final dx = b[0] - a[0];
      final dy = b[1] - a[1];
      final len = math.sqrt(dx * dx + dy * dy);
      if (len == 0) continue;
      final nx = -dy / len;
      final ny = dx / len;
      right.add([a[0] + nx * radiusM, a[1] + ny * radiusM]);
      right.add([b[0] + nx * radiusM, b[1] + ny * radiusM]);
      left.add([a[0] - nx * radiusM, a[1] - ny * radiusM]);
      left.add([b[0] - nx * radiusM, b[1] - ny * radiusM]);
    }

    final first = unique.first;
    final second = unique[1];
    final startDir = math.atan2(second[1] - first[1], second[0] - first[0]);
    final startCap = _arc(first, radiusM, startDir + math.pi / 2, math.pi);

    final last = unique.last;
    final penult = unique[unique.length - 2];
    final endDir = math.atan2(last[1] - penult[1], last[0] - penult[0]);
    final endCap = _arc(last, radiusM, endDir - math.pi / 2, math.pi);

    final ring = <List<double>>[];
    ring.addAll(right);
    ring.addAll(endCap);
    ring.addAll(left.reversed);
    ring.addAll(startCap);
    ring.add(List<double>.from(ring.first));

    final coords = ring.map(toLngLat).toList();
    return {
      'type': 'Polygon',
      'coordinates': [coords],
    };
  }

  static List<List<double>> _arc(
    List<double> center,
    double radius,
    double startAngle,
    double sweep,
  ) {
    final out = <List<double>>[];
    for (var i = 0; i <= _capSegments; i++) {
      final t = i / _capSegments;
      final a = startAngle + sweep * t;
      out.add([
        center[0] + radius * math.cos(a),
        center[1] + radius * math.sin(a),
      ]);
    }
    return out;
  }
}
