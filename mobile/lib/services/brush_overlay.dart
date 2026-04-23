import 'package:maplibre_gl/maplibre_gl.dart';

/// Render-side contract used by `BrushController`. Tests substitute a fake
/// so the controller's state logic can be exercised without a live
/// MapLibre surface.
abstract class BrushOverlaySurface {
  bool get isAttached;
  Future<void> setPreview(Map<String, dynamic> geometry, String colorHex);
  Future<void> clear();
  Future<void> detach();
}

/// Semi-transparent fill of the in-progress brush stroke. Mirrors the
/// `brush-preview` source + fill layer in web/src/lib/brush.svelte.js.
class BrushOverlay implements BrushOverlaySurface {
  BrushOverlay._(this._controller);

  static const String sourceId = 'brush-preview';
  static const String fillLayerId = 'brush-preview-fill';

  static const Map<int, String> _colors = {
    -7: '#B8342E',
    -3: '#D94A4A',
    -1: '#EF8379',
    0: '#8A95A1',
    1: '#7FD9C9',
    3: '#2EB8A8',
    7: '#0E7E72',
  };
  static const String _fallbackColor = '#8A95A1';

  /// Get the hex color for a given rating value, or the fallback gray if not found.
  static String colorFor(int value) => _colors[value] ?? _fallbackColor;

  final MapLibreMapController _controller;
  bool _attached = false;
  String? _lastColorHex;

  @override
  bool get isAttached => _attached;

  /// Create and attach the brush preview source and fill layer to the current style.
  ///
  /// [belowLayerId] allows layering the brush preview below other overlays.
  /// Pass `null` to add at the top of the style. Returns an attached overlay
  /// ready to receive geometry updates via [setPreview].
  static Future<BrushOverlay> attach(
    MapLibreMapController controller, {
    String? belowLayerId,
  }) async {
    final overlay = BrushOverlay._(controller);

    await controller.addGeoJsonSource(
      sourceId,
      const {'type': 'FeatureCollection', 'features': []},
    );
    await controller.addFillLayer(
      sourceId,
      fillLayerId,
      const FillLayerProperties(
        fillColor: _fallbackColor,
        fillOpacity: 0.3,
      ),
      belowLayerId: belowLayerId,
      enableInteraction: false,
    );
    overlay._attached = true;
    return overlay;
  }

  /// Update the preview geometry and color, caching the color to avoid redundant layer updates.
  ///
  /// Since [setPreview] is called on every pointer-move event, the geometry always
  /// changes but the color usually stays the same within a stroke. This method skips
  /// [setLayerProperties] calls when the color hex hasn't changed.
  @override
  Future<void> setPreview(
    Map<String, dynamic> geometry,
    String colorHex,
  ) async {
    if (!_attached) return;
    await _controller.setGeoJsonSource(sourceId, {
      'type': 'FeatureCollection',
      'features': [
        {'type': 'Feature', 'properties': {}, 'geometry': geometry},
      ],
    });
    if (colorHex != _lastColorHex) {
      await _controller.setLayerProperties(
        fillLayerId,
        FillLayerProperties(fillColor: colorHex, fillOpacity: 0.3),
      );
      _lastColorHex = colorHex;
    }
  }

  /// Clear all rendered geometry without removing the source or layer.
  ///
  /// The preview will be hidden until the next [setPreview] call.
  @override
  Future<void> clear() async {
    if (!_attached) return;
    await _controller.setGeoJsonSource(sourceId, const {
      'type': 'FeatureCollection',
      'features': [],
    });
  }

  /// Remove the fill layer and source from the style. Safe to call multiple times.
  ///
  /// This should be called during screen disposal to clean up all resources.
  @override
  Future<void> detach() async {
    if (!_attached) return;
    _attached = false;
    try {
      await _controller.removeLayer(fillLayerId);
    } catch (_) {}
    try {
      await _controller.removeSource(sourceId);
    } catch (_) {}
  }
}
