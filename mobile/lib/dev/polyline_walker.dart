import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class WalkerPoint {
  const WalkerPoint(this.latLng, this.bearingDeg);
  final LatLng latLng;
  final double bearingDeg;
}

class PolylineWalker {
  PolylineWalker(List<LatLng> points)
      : _points = List.unmodifiable(points),
        _cumulative = _buildCumulative(points),
        _bearings = _buildBearings(points) {
    if (points.length < 2) {
      throw ArgumentError('PolylineWalker requires >= 2 points');
    }
  }

  final List<LatLng> _points;
  final List<double> _cumulative; // length == _points.length
  final List<double> _bearings;   // length == _points.length - 1

  double get totalLengthM => _cumulative.last;

  WalkerPoint positionAt(double cumulativeM) {
    if (cumulativeM <= 0) {
      return WalkerPoint(_points.first, _bearings.first);
    }
    if (cumulativeM >= totalLengthM) {
      return WalkerPoint(_points.last, _bearings.last);
    }
    // Find segment whose end-cumulative >= cumulativeM.
    var lo = 1;
    var hi = _cumulative.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_cumulative[mid] < cumulativeM) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final segIdx = lo - 1;
    final segStart = _cumulative[segIdx];
    final segEnd = _cumulative[segIdx + 1];
    // Guard against zero-length segments: duplicate points produce div-by-zero in t.
    if (segEnd - segStart < 1e-9) {
      return WalkerPoint(_points[segIdx + 1], _bearings[segIdx]);
    }
    final t = (cumulativeM - segStart) / (segEnd - segStart);
    final a = _points[segIdx];
    final b = _points[segIdx + 1];
    final lat = a.latitude + (b.latitude - a.latitude) * t;
    final lng = a.longitude + (b.longitude - a.longitude) * t;
    return WalkerPoint(LatLng(lat, lng), _bearings[segIdx]);
  }

  static List<double> _buildCumulative(List<LatLng> points) {
    final out = <double>[0];
    for (var i = 1; i < points.length; i++) {
      final d = Geolocator.distanceBetween(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
      out.add(out.last + d);
    }
    return out;
  }

  static List<double> _buildBearings(List<LatLng> points) {
    final out = <double>[];
    for (var i = 1; i < points.length; i++) {
      final b = Geolocator.bearingBetween(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
      // Normalize to [0, 360).
      out.add((b % 360 + 360) % 360);
    }
    return out;
  }
}
