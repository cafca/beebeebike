import 'package:flutter/gestures.dart';

/// Single-pointer-only pan for paint mode.
///
/// A stock [PanGestureRecognizer] keeps tracking its first pointer even after
/// a second finger lands, so a user trying to pinch/pan the (static) map
/// would also paint a stroke with the first finger. This variant rejects the
/// gesture as soon as a second pointer enters, which fires `onCancel` on the
/// owner so it can drop the in-progress stroke.
///
/// Map-camera gestures are disabled while paint mode is active, so there's
/// no sibling recognizer to hand off to — the extra pointers are simply
/// ignored.
class PaintPanGestureRecognizer extends PanGestureRecognizer {
  PaintPanGestureRecognizer({super.debugOwner});

  int _activePointers = 0;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _activePointers++;
    if (_activePointers >= 2) {
      resolve(GestureDisposition.rejected);
      return;
    }
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    super.handleEvent(event);
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (_activePointers > 0) _activePointers--;
    }
  }
}
