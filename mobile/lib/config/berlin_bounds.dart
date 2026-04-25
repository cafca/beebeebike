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

  factory Bbox.fromJson(Map<String, dynamic> json) => Bbox(
        west: (json['west'] as num).toDouble(),
        south: (json['south'] as num).toDouble(),
        east: (json['east'] as num).toDouble(),
        north: (json['north'] as num).toDouble(),
      );

  final double west;
  final double south;
  final double east;
  final double north;

  /// Backend format: "west,south,east,north".
  String toQueryString() => '$west,$south,$east,$north';

  /// Inclusive containment check. Edge points count as inside.
  bool contains(double lat, double lng) =>
      lng >= west && lng <= east && lat >= south && lat <= north;

  Map<String, dynamic> toJson() => {
        'west': west,
        'south': south,
        'east': east,
        'north': north,
      };

  @override
  bool operator ==(Object other) =>
      other is Bbox &&
      other.west == west &&
      other.south == south &&
      other.east == east &&
      other.north == north;

  @override
  int get hashCode => Object.hash(west, south, east, north);
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
