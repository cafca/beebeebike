/// Axis-aligned bounding box in EPSG:4326 degrees. Flattened (not
/// `LatLngBounds`) so it can be used in pure-Dart tests without pulling a
/// MapLibre controller.
class Bbox {
  const Bbox({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  final double west;
  final double south;
  final double east;
  final double north;

  /// Backend format: "west,south,east,north".
  String toQueryString() => '$west,$south,$east,$north';
}

/// Full-sync bbox for rating areas. Covers Berlin plus a ~5km padding ring
/// so polygons painted near the edge of the user's normal working area
/// aren't clipped at the boundary. Kept wider than the camera-clamp
/// `_berlinBounds` in `map_screen.dart` on purpose.
const Bbox kBerlinSyncBbox = Bbox(
  west: 12.9,
  south: 52.25,
  east: 13.9,
  north: 52.75,
);
