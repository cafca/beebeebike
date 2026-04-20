import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/route_preview.dart';

const _routeLineColor = '#2E6F66';
const _markerFillColor = '#2E6F66';
const _markerStrokeColor = '#ffffff';

List<LatLng> _decodeLineString(Map<String, dynamic> geometry) {
  final coords = geometry['coordinates'] as List<dynamic>;
  return coords
      .map((c) => LatLng((c as List)[1] as double, c[0] as double))
      .toList();
}

LatLngBounds _boundsFor(List<LatLng> points) {
  var minLat = points.first.latitude;
  var maxLat = points.first.latitude;
  var minLng = points.first.longitude;
  var maxLng = points.first.longitude;
  for (final p in points.skip(1)) {
    if (p.latitude < minLat) minLat = p.latitude;
    if (p.latitude > maxLat) maxLat = p.latitude;
    if (p.longitude < minLng) minLng = p.longitude;
    if (p.longitude > maxLng) maxLng = p.longitude;
  }
  return LatLngBounds(
    southwest: LatLng(minLat, minLng),
    northeast: LatLng(maxLat, maxLng),
  );
}

class RouteOverlay {
  RouteOverlay._(this._line, this._origin, this._destination);

  final Line _line;
  final Circle _origin;
  final Circle _destination;

  static Future<RouteOverlay> draw(
    MapLibreMapController controller,
    RoutePreview preview, {
    bool fitCamera = true,
  }) async {
    final coords = _decodeLineString(preview.geometry);
    final line = await controller.addLine(LineOptions(
      geometry: coords,
      lineColor: _routeLineColor,
      lineWidth: 5.0,
      lineOpacity: 0.9,
    ));
    final origin = await controller.addCircle(CircleOptions(
      geometry: coords.first,
      circleRadius: 8.0,
      circleColor: _markerFillColor,
      circleStrokeColor: _markerStrokeColor,
      circleStrokeWidth: 2.0,
    ));
    final destination = await controller.addCircle(CircleOptions(
      geometry: coords.last,
      circleRadius: 8.0,
      circleColor: _markerFillColor,
      circleStrokeColor: _markerStrokeColor,
      circleStrokeWidth: 2.0,
    ));
    if (fitCamera) {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          _boundsFor(coords),
          left: 40,
          top: 100,
          right: 40,
          bottom: 240,
        ),
      );
    }
    return RouteOverlay._(line, origin, destination);
  }

  Future<void> remove(MapLibreMapController controller) async {
    await controller.removeLine(_line);
    await controller.removeCircle(_origin);
    await controller.removeCircle(_destination);
  }
}
