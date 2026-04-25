import 'package:maplibre_gl/maplibre_gl.dart';

/// Render-side contract used by `RatingOverlayController`. `RatingOverlay` is
/// the production implementation; tests substitute a fake so the controller's
/// fetch/cancel/auth-change logic can be exercised without a real MapLibre
/// surface.
abstract class RatingOverlaySurface {
  bool get isAttached;
  Future<void> update(Map<String, dynamic> featureCollection);
  Future<void> clear();
  Future<void> detach();
}

/// MapLibre source + fill/line layers that render the user's painted rating
/// polygons. Mirrors the web implementation in web/src/lib/overlay.js.
///
/// Lifecycle:
///   1. [attach] — creates an empty GeoJSON source plus a fill layer and an
///      outline layer. Call once after [MapLibreMapController] is created.
///   2. [update] — replaces the source data with a new FeatureCollection.
///   3. [detach] — removes both layers and the source. Call on screen dispose.
class RatingOverlay implements RatingOverlaySurface {
  RatingOverlay._(this._controller);

  static const String sourceId = 'ratings';
  static const String fillLayerId = 'ratings-fill';
  static const String lineLayerId = 'ratings-outline';

  // Web parity — see web/src/lib/overlay.js
  static const Map<int, String> _colors = {
    -7: '#c0392b', // dark red
    -3: '#e74c3c', // medium red
    -1: '#f1948a', // pale red
    1: '#76d7c4', // pale teal
    3: '#1abc9c', // teal
    7: '#0e6655', // dark teal
  };
  static const String _fallbackColor = '#6b7280';

  final MapLibreMapController _controller;
  bool _attached = false;

  @override
  bool get isAttached => _attached;

  /// Add the empty source and both layers to the current style.
  ///
  /// [belowLayerId] lets the caller keep other overlays (e.g. route line) on
  /// top. Pass `null` to add at the top of the style.
  static Future<RatingOverlay> attach(
    MapLibreMapController controller, {
    String? belowLayerId,
  }) async {
    final overlay = RatingOverlay._(controller);

    await controller.addGeoJsonSource(
      sourceId,
      const <String, dynamic>{'type': 'FeatureCollection', 'features': <dynamic>[]},
    );

    final colorExpr = _matchExpression();

    await controller.addFillLayer(
      sourceId,
      fillLayerId,
      FillLayerProperties(
        fillColor: colorExpr,
        fillOpacity: 0.4,
      ),
      belowLayerId: belowLayerId,
      enableInteraction: false,
    );

    await controller.addLineLayer(
      sourceId,
      lineLayerId,
      LineLayerProperties(
        lineColor: colorExpr,
        lineWidth: 1.0,
        lineOpacity: 0.7,
      ),
      belowLayerId: belowLayerId,
      enableInteraction: false,
    );

    overlay._attached = true;
    return overlay;
  }

  /// Replace the source data with the given FeatureCollection.
  @override
  Future<void> update(Map<String, dynamic> featureCollection) async {
    if (!_attached) return;
    await _controller.setGeoJsonSource(sourceId, featureCollection);
  }

  /// Clear all rendered polygons without detaching the layers.
  @override
  Future<void> clear() => update(const <String, dynamic>{
        'type': 'FeatureCollection',
        'features': <dynamic>[],
      });

  /// Remove layers + source. Safe to call multiple times.
  @override
  Future<void> detach() async {
    if (!_attached) return;
    _attached = false;
    try {
      await _controller.removeLayer(lineLayerId);
    } on Object catch (_) {}
    try {
      await _controller.removeLayer(fillLayerId);
    } on Object catch (_) {}
    try {
      await _controller.removeSource(sourceId);
    } on Object catch (_) {}
  }

  /// Build a MapLibre `match` expression on the `value` property of each
  /// feature. Same expression works for both `fill-color` and `line-color`
  /// because the branches map rating → hex and don't reference the property
  /// name.
  static List<dynamic> _matchExpression() {
    final expr = <dynamic>[
      'match',
      ['get', 'value'],
    ];
    for (final entry in _colors.entries) {
      expr
        ..add(entry.key)
        ..add(entry.value);
    }
    expr.add(_fallbackColor);
    return expr;
  }
}
