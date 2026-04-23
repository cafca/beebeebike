import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../api/ratings_paint_api.dart';
import '../providers/rating_overlay_provider.dart';
import '../services/brush_geometry.dart';
import '../services/brush_overlay.dart';

class TapFeature {
  const TapFeature({required this.areaId, required this.geometry});
  final int areaId;
  final Map<String, dynamic> geometry;
}

typedef TapFeatureLookup = Future<TapFeature?> Function(LatLng point);

@immutable
class BrushState {
  const BrushState({
    this.value = 1,
    this.paintMode = false,
    this.canUndo = false,
    this.canRedo = false,
  });

  final int value;
  final bool paintMode;
  final bool canUndo;
  final bool canRedo;

  BrushState copyWith({
    int? value,
    bool? paintMode,
    bool? canUndo,
    bool? canRedo,
  }) =>
      BrushState(
        value: value ?? this.value,
        paintMode: paintMode ?? this.paintMode,
        canUndo: canUndo ?? this.canUndo,
        canRedo: canRedo ?? this.canRedo,
      );
}

void _log(String msg) {
  if (kDebugMode) debugPrint(msg);
}

class BrushController extends Notifier<BrushState> {
  BrushOverlaySurface? _overlay;
  final List<LatLng> _stroke = [];
  double _lastZoom = 14;
  bool _submitting = false;

  @override
  BrushState build() => const BrushState();

  void attach({required BrushOverlaySurface surface}) {
    _overlay = surface;
  }

  Future<void> detach() async {
    final s = _overlay;
    _overlay = null;
    _stroke.clear();
    await s?.detach();
  }

  void setValue(int v) {
    state = state.copyWith(value: v, paintMode: true);
  }

  void togglePaintMode() {
    final next = !state.paintMode;
    if (!next) {
      _stroke.clear();
      unawaited(_overlay?.clear());
    }
    state = state.copyWith(paintMode: next);
  }

  void forceOff() {
    if (!state.paintMode) return;
    _stroke.clear();
    unawaited(_overlay?.clear());
    state = state.copyWith(paintMode: false);
  }

  /// Abandon an in-progress stroke without submitting. Called when a second
  /// pointer lands on the canvas — the stroke was meant to be a pan, not a
  /// paint.
  void cancelStroke() {
    if (_stroke.isEmpty) return;
    _stroke.clear();
    unawaited(_overlay?.clear());
  }

  void startStroke(LatLng first) {
    _stroke
      ..clear()
      ..add(first);
  }

  void addPoint(LatLng p, double zoom) {
    _stroke.add(p);
    _lastZoom = zoom;
    final geom = BrushGeometry.buildPolygon(points: _stroke, zoom: zoom);
    if (geom != null) {
      unawaited(_overlay?.setPreview(geom, BrushOverlay.colorFor(state.value)));
    }
  }

  Future<void> endStroke({required TapFeatureLookup tapFeatureLookup}) async {
    if (_submitting) return;
    _submitting = true;
    try {
      if (_stroke.length < 2) {
        final tap = _stroke.isEmpty ? null : _stroke.first;
        if (tap == null) return;
        final hit = await tapFeatureLookup(tap);
        if (hit == null) return;
        await _submit(
          geometry: hit.geometry,
          targetId: hit.areaId,
        );
        return;
      }
      final geom = BrushGeometry.buildPolygon(
        points: List.unmodifiable(_stroke),
        zoom: _lastZoom,
      );
      if (geom == null) return;
      await _submit(geometry: geom, targetId: null);
    } finally {
      _stroke.clear();
      unawaited(_overlay?.clear());
      _submitting = false;
    }
  }

  Future<void> undo() async {
    try {
      final api = ref.read(ratingsPaintApiProvider);
      final r = await api.undo();
      state = state.copyWith(canUndo: r.canUndo, canRedo: r.canRedo);
      ref.read(ratingOverlayControllerProvider.notifier).refreshAfterPaint();
    } catch (e) {
      _log('brush: undo failed: $e');
    }
  }

  Future<void> redo() async {
    try {
      final api = ref.read(ratingsPaintApiProvider);
      final r = await api.redo();
      state = state.copyWith(canUndo: r.canUndo, canRedo: r.canRedo);
      ref.read(ratingOverlayControllerProvider.notifier).refreshAfterPaint();
    } catch (e) {
      _log('brush: redo failed: $e');
    }
  }

  Future<void> _submit({
    required Map<String, dynamic> geometry,
    required int? targetId,
  }) async {
    try {
      final api = ref.read(ratingsPaintApiProvider);
      final r = await api.paint(
        geometry: geometry,
        value: state.value,
        targetId: targetId,
      );
      state = state.copyWith(canUndo: r.canUndo, canRedo: r.canRedo);
      final overlay = ref.read(ratingOverlayControllerProvider.notifier);
      final canAppendLocally = targetId == null &&
          r.clippedCount == 0 &&
          r.deletedCount == 0 &&
          r.createdId != null;
      if (canAppendLocally) {
        await overlay.appendLocal(
          geometry: geometry,
          value: state.value,
          id: r.createdId,
        );
      } else {
        await overlay.refreshAfterPaint();
      }
    } catch (e) {
      _log('brush: paint failed: $e');
    }
  }
}

final brushControllerProvider =
    NotifierProvider<BrushController, BrushState>(BrushController.new);
