import 'package:maplibre_gl/maplibre_gl.dart';

/// Minimum zoom at which the rating overlay fetches data. Below this we
/// would pull too many polygons for too little visual benefit.
const double kRatingOverlayMinZoom = 10.0;

/// How much the fetched bbox is expanded around the current viewport. A
/// value of 2.0 means the request covers 2x the width and 2x the height of
/// the visible map, centered on the viewport — roughly 50% margin on each
/// side so small pans stay within the already-fetched area.
const double kRatingOverlayBboxExpansion = 2.0;

/// Fraction of the last fetched (expanded) bbox that we consider "safe". If
/// the current viewport fits entirely inside this centered inner window we
/// skip the refetch. 0.6 ≈ can pan 20% of expanded-width in any direction
/// before a new request is triggered.
const double kRatingOverlaySafeInnerFraction = 0.6;

/// Axis-aligned bounding box in EPSG:4326 degrees. All four fields are in
/// the same units as [LatLngBounds] but flattened so this can be used in
/// pure Dart tests without pulling a MapLibre controller.
class Bbox {
  const Bbox({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  factory Bbox.fromLatLngBounds(LatLngBounds bounds) => Bbox(
        west: bounds.southwest.longitude,
        south: bounds.southwest.latitude,
        east: bounds.northeast.longitude,
        north: bounds.northeast.latitude,
      );

  final double west;
  final double south;
  final double east;
  final double north;

  double get width => east - west;
  double get height => north - south;
  double get centerLng => (west + east) / 2;
  double get centerLat => (south + north) / 2;

  /// Scale this bbox around its center. [factor] of 2.0 doubles width and
  /// height (4x area). Used both to expand the viewport before fetching
  /// and to shrink the last-fetched bbox to an "inner safe" window.
  Bbox scaleAroundCenter(double factor) {
    final halfW = width * factor / 2;
    final halfH = height * factor / 2;
    return Bbox(
      west: centerLng - halfW,
      south: centerLat - halfH,
      east: centerLng + halfW,
      north: centerLat + halfH,
    );
  }

  /// Whether `other` is fully contained in this bbox.
  bool contains(Bbox other) =>
      other.west >= west &&
      other.east <= east &&
      other.south >= south &&
      other.north <= north;

  /// Backend format: "west,south,east,north".
  String toQueryString() => '$west,$south,$east,$north';
}

/// Decision returned by [decideFetch].
///
/// - [shouldFetch] true means issue a network request with [fetchBbox].
/// - [shouldFetch] false means the current overlay still covers the visible
///   area; no network needed.
class FetchDecision {
  const FetchDecision({required this.shouldFetch, this.fetchBbox});

  final bool shouldFetch;
  final Bbox? fetchBbox;
}

/// Pure decision logic used by [RatingOverlayController].
///
/// Inputs:
/// - [zoom] current camera zoom.
/// - [viewport] the bbox currently visible on screen.
/// - [lastFetched] the expanded bbox previously requested from the backend,
///   or null if nothing has been fetched yet.
///
/// Returns whether to refetch and, if so, what bbox to request (the
/// viewport expanded by [kRatingOverlayBboxExpansion]).
FetchDecision decideFetch({
  required double zoom,
  required Bbox viewport,
  required Bbox? lastFetched,
}) {
  if (zoom < kRatingOverlayMinZoom) {
    return const FetchDecision(shouldFetch: false);
  }
  if (lastFetched != null) {
    final inner = lastFetched.scaleAroundCenter(kRatingOverlaySafeInnerFraction);
    if (inner.contains(viewport)) {
      return const FetchDecision(shouldFetch: false);
    }
  }
  return FetchDecision(
    shouldFetch: true,
    fetchBbox: viewport.scaleAroundCenter(kRatingOverlayBboxExpansion),
  );
}
