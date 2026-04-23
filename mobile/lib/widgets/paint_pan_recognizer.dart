import 'package:flutter/gestures.dart';

/// A [ScaleGestureRecognizer] that only claims the gesture when at least two
/// pointers are down. Mounted on the outer `RawGestureDetector` in paint mode
/// alongside [PaintPanGestureRecognizer] so single-finger drags go to the
/// brush and two-finger pinch/pan drives the map manually.
///
/// The stock [ScaleGestureRecognizer] accepts single-pointer focal-point
/// drags (once they cross pan slop), which would steal paint strokes from us.
class MultiPointerScaleGestureRecognizer extends ScaleGestureRecognizer {
  MultiPointerScaleGestureRecognizer({super.debugOwner});

  int _pointerCount = 0;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _pointerCount++;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (_pointerCount > 0) _pointerCount--;
    }
    super.handleEvent(event);
  }

  @override
  void resolve(GestureDisposition disposition) {
    if (disposition == GestureDisposition.accepted && _pointerCount < 2) {
      // Single-pointer focal drag — refuse to claim, leave it for
      // [PaintPanGestureRecognizer] to pick up. Stays in "possible" state so
      // that if a second pointer lands, the next advance attempt can accept.
      return;
    }
    super.resolve(disposition);
  }
}

/// A [PanGestureRecognizer] variant for the brush paint mode.
///
/// Two tweaks over the default:
///
///   * **Single-pointer enforcement.** If a second pointer lands while a
///     pan is already being tracked, we reject our claim on the first
///     pointer and bail. That lets the sibling
///     [MultiPointerScaleGestureRecognizer] win the arena and drive
///     pinch/pan on the map. If the drag had already been accepted (past
///     slop) the parent fires `onCancel` for us so the caller can drop
///     the in-progress stroke.
///
///   * **Double-tap-drag guard.** The second tap of iOS's double-tap-drag
///     zoom gesture fires as a lone `PointerDown`. We ignore any
///     `addAllowedPointer` that arrives within 300 ms of the last
///     `PointerUp` so native zoom gesture handling can claim it.
///
/// Mirrors `web/src/lib/brush.svelte.js` (second-pointer cancel +
/// `lastTouchEndTime` guard).
class PaintPanGestureRecognizer extends PanGestureRecognizer {
  PaintPanGestureRecognizer({super.debugOwner});

  static const Duration _doubleTapGuard = Duration(milliseconds: 300);

  DateTime? _lastPointerUp;
  bool _tracking = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_tracking) {
      // Second pointer during an active drag → hand off to the sibling
      // MultiPointerScaleGestureRecognizer.
      resolve(GestureDisposition.rejected);
      return;
    }
    final last = _lastPointerUp;
    if (last != null && DateTime.now().difference(last) < _doubleTapGuard) {
      // Second tap of a double-tap-drag-zoom — don't start a brush stroke.
      return;
    }
    _tracking = true;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    super.handleEvent(event);
    if (event is PointerUpEvent) {
      _lastPointerUp = DateTime.now();
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _tracking = false;
    super.didStopTrackingLastPointer(pointer);
  }
}
