import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:clipper2/clipper2.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Brush stroke sampling + polygon inflation used by `BrushController`.
///
/// Uses clipper2's `inflatePathsD` with round caps/joins so self-intersecting
/// strokes (loops, doubled-back paths) resolve into a single valid region
/// with proper holes instead of a self-crossing ring.
class BrushGeometry {
  BrushGeometry._();

  static const double minMovePx = 4;
  static const double brushPx = 27;
  static const double minRadiusKm = 0.005;

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

  /// Inflate a polyline into a GeoJSON Polygon (with holes if the stroke
  /// loops back on itself). Returns `null` when the stroke has < 2 unique
  /// points.
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

    final path = <PointD>[];
    double? lastX;
    double? lastY;
    for (final p in points) {
      final x = (p.longitude - p0.longitude) * mPerDegLon;
      final y = (p.latitude - p0.latitude) * mPerDegLat;
      if (lastX == null || x != lastX || y != lastY) {
        path.add(PointD(x, y));
        lastX = x;
        lastY = y;
      }
    }
    if (path.length < 2) return null;

    final inflated = Clipper.inflatePathsD(
      paths: <PathD>[path],
      delta: radiusM,
      joinType: JoinType.round,
      endType: EndType.round,
    );
    if (inflated.isEmpty) return null;

    List<List<double>> ringToCoords(PathD ring) {
      final coords = <List<double>>[
        for (final pt in ring)
          [p0.longitude + pt.x / mPerDegLon, p0.latitude + pt.y / mPerDegLat],
      ];
      if (coords.isEmpty) return coords;
      final f = coords.first;
      final l = coords.last;
      if (f[0] != l[0] || f[1] != l[1]) coords.add(List<double>.from(f));
      return coords;
    }

    double signedArea(PathD ring) {
      var sum = 0.0;
      for (var i = 0; i < ring.length; i++) {
        final a = ring[i];
        final b = ring[(i + 1) % ring.length];
        sum += (b.x - a.x) * (b.y + a.y);
      }
      return -sum / 2; // positive = CCW
    }

    final outers = <PathD>[];
    final holes = <PathD>[];
    for (final ring in inflated) {
      if (ring.length < 3) continue;
      if (signedArea(ring) >= 0) {
        outers.add(ring);
      } else {
        holes.add(ring);
      }
    }
    if (outers.isEmpty) return null;

    // A single brush stroke is a connected polyline, so inflatePathsD
    // produces one outer ring plus zero or more interior holes. Attach
    // all holes to the sole outer; if clipper ever returns multiple
    // outers, fall back to a MultiPolygon with holes on the first.
    if (outers.length == 1) {
      return {
        'type': 'Polygon',
        'coordinates': [
          ringToCoords(outers.first),
          for (final h in holes) ringToCoords(h),
        ],
      };
    }

    return {
      'type': 'MultiPolygon',
      'coordinates': [
        [
          ringToCoords(outers.first),
          for (final h in holes) ringToCoords(h),
        ],
        for (final o in outers.skip(1))
          [ringToCoords(o)],
      ],
    };
  }
}
