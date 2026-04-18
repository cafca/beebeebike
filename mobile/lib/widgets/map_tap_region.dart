import 'dart:async';

import 'package:flutter/material.dart';

/// Wraps a child (typically [MapLibreMap]) and reports single-finger taps
/// without claiming pointers in the gesture arena. Multi-touch and drag
/// sequences pass through to the underlying platform view, so pinch-to-zoom
/// and rotate keep working.
class MapTapRegion extends StatefulWidget {
  const MapTapRegion({
    super.key,
    required this.child,
    required this.onTap,
    this.maxMovement = 8.0,
    this.maxDuration = const Duration(milliseconds: 300),
  });

  final Widget child;
  final ValueChanged<Offset> onTap;
  final double maxMovement;
  final Duration maxDuration;

  @override
  State<MapTapRegion> createState() => _MapTapRegionState();
}

class _MapTapRegionState extends State<MapTapRegion> {
  int? _activePointer;
  Offset? _downPos;
  Timer? _expiry;

  void _reset() {
    _activePointer = null;
    _downPos = null;
    _expiry?.cancel();
    _expiry = null;
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (_activePointer != null) {
          _reset();
          return;
        }
        _activePointer = event.pointer;
        _downPos = event.localPosition;
        _expiry = Timer(widget.maxDuration, _reset);
      },
      onPointerMove: (event) {
        if (event.pointer != _activePointer) return;
        final origin = _downPos;
        if (origin == null) return;
        if ((event.localPosition - origin).distance > widget.maxMovement) {
          _reset();
        }
      },
      onPointerUp: (event) {
        if (event.pointer != _activePointer) {
          _reset();
          return;
        }
        final origin = _downPos;
        _reset();
        if (origin == null) return;
        if ((event.localPosition - origin).distance > widget.maxMovement) {
          return;
        }
        widget.onTap(event.localPosition);
      },
      onPointerCancel: (_) => _reset(),
      child: widget.child,
    );
  }
}
