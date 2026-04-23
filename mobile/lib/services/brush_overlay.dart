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
    -7: '#c0392b',
    -3: '#e74c3c',
    -1: '#f1948a',
    0: '#6b7280',
    1: '#76d7c4',
    3: '#1abc9c',
    7: '#0e6655',
  };

  static String colorFor(int value) => _colors[value] ?? '#6b7280';

  final MapLibreMapController _controller;
  bool _attached = false;

  @override
  bool get isAttached => _attached;

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
        fillColor: '#60a5fa',
        fillOpacity: 0.3,
      ),
      belowLayerId: belowLayerId,
      enableInteraction: false,
    );
    overlay._attached = true;
    return overlay;
  }

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
    await _controller.setLayerProperties(
      fillLayerId,
      FillLayerProperties(fillColor: colorHex, fillOpacity: 0.3),
    );
  }

  @override
  Future<void> clear() async {
    if (!_attached) return;
    await _controller.setGeoJsonSource(sourceId, const {
      'type': 'FeatureCollection',
      'features': [],
    });
  }

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
